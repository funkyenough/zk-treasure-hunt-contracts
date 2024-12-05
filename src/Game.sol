// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// interface IGames {}
// contract GameFactory {}

/**
 @title A ZK Treasure Hunt Game
 @author funkyenough, kota

 */
contract Game {
    string public name;
    string public description;
    uint256 public immutable registrationEndTime;
    uint256 public immutable gameEndTime;
    uint256 public immutable resolutionEndTime;
    uint256 public immutable registrationFee;

    mapping(address => bool) public hasParticipated;
    mapping(address => Coordinate[]) public playerCoordinates;

    Treasure public treasure;
    Winner public winner;

    struct Coordinate {
        uint256 x;
        uint256 y;
    }

    struct Treasure {
        bytes32 treasureHash;
        Coordinate treasureCoordinate;
    }

    struct Winner {
        address latestWinner;
        uint256 shortestDistance;
        Coordinate closestCoordinate;
        bool winnerDeclared;
    }

    enum GamePhase {
        REGISTRATION,
        ACTIVE,
        RESOLUTION,
        COMPLETED
    }

    event playerHasDeposited(address indexed player);
    event winnerUpdated(
        address indexed player,
        uint256 indexed distance,
        Coordinate indexed coordinate
    );

    error registrationFeeIsIncorrect();

    error NotInPhase();
    error notInResolutionPhaseOrCompletion();

    error playerAlreadyRegistered();
    error playerNotRegistered();
    error playerNotWinner();
    error playerCooridinateTooFar();

    error noLatestWinner();
    error winnerNotDeclared();

    error InvalidTreasureCoordinate();

    constructor(
        string memory _name,
        string memory _description,
        uint256 _registrationEndTime,
        uint256 _gameEndTime,
        uint256 _resolutionDuration,
        uint256 _registrationFee,
        bytes32 _treasureHash
    ) {
        name = _name;
        description = _description;
        registrationEndTime = _registrationEndTime;
        gameEndTime = _gameEndTime;
        resolutionEndTime = gameEndTime + _resolutionDuration;
        registrationFee = _registrationFee;

        treasure = Treasure({
            treasureHash: _treasureHash,
            treasureCoordinate: Coordinate({x: 0, y: 0}) // This is kind of not very good ...?
        });

        winner = Winner({
            latestWinner: address(0),
            shortestDistance: type(uint256).max,
            closestCoordinate: Coordinate({x: 0, y: 0}), // This is also really bad.
            winnerDeclared: false
        });
    }

    modifier onlyInPhase(GamePhase phase) {
        if (getCurrentPhase() != phase) revert NotInPhase();
        _;
    }

    modifier onlyRegistered() {
        if (!hasParticipated[msg.sender]) revert playerNotRegistered();
        _;
    }

    modifier onlywinnerDeclared() {
        if (!winner.winnerDeclared) revert winnerNotDeclared();
        _;
    }

    function getCurrentPhase() public view returns (GamePhase) {
        if (block.timestamp < registrationEndTime)
            return GamePhase.REGISTRATION;
        if (block.timestamp < gameEndTime) return GamePhase.ACTIVE;
        if (block.timestamp < resolutionEndTime) return GamePhase.RESOLUTION;
        return GamePhase.COMPLETED;
    }

    function determineWinner() public onlyInPhase(GamePhase.COMPLETED) {
        if (winner.latestWinner == address(0)) revert noLatestWinner();
        winner.winnerDeclared = true;
    }

    function getWinner()
        public
        view
        onlyInPhase(GamePhase.COMPLETED)
        returns (address)
    {
        if (winner.latestWinner == address(0)) revert noLatestWinner();
        return winner.latestWinner;
    }

    function deposit() external payable onlyInPhase(GamePhase.REGISTRATION) {
        if (msg.value != registrationFee) revert registrationFeeIsIncorrect();
        if (hasParticipated[msg.sender]) revert playerAlreadyRegistered();

        hasParticipated[msg.sender] = true;
        emit playerHasDeposited(msg.sender);
    }

    // The difficult part is to make this function only callable by the mobile client while still remaining permissionless...
    function addPlayerCoordinate(
        uint256 _x,
        uint256 _y
    ) external onlyInPhase(GamePhase.ACTIVE) onlyRegistered {
        playerCoordinates[msg.sender].push(Coordinate(_x, _y));
    }

    function revealTreasureCoordinate(uint256 _x, uint256 _y) external {
        if (
            getCurrentPhase() != GamePhase.RESOLUTION ||
            getCurrentPhase() != GamePhase.COMPLETED
        ) revert notInResolutionPhaseOrCompletion();
        if (!verifyTreasureCoordinate(_x, _y))
            revert InvalidTreasureCoordinate();
        treasure.treasureCoordinate.x = _x;
        treasure.treasureCoordinate.y = _y;
    }

    // Using keccak for now
    function verifyTreasureCoordinate(
        uint256 _x,
        uint256 _y
    ) internal view returns (bool) {
        bytes32 _treasureHash = keccak256(abi.encodePacked(_x, _y));
        return (treasure.treasureHash == _treasureHash);
    }

    // Anyone can call this function to update the winner
    function updateWinner(address player, uint256 coordinateId) external {
        if (!hasParticipated[player]) revert playerAlreadyRegistered();
        Coordinate memory coordinate = playerCoordinates[player][coordinateId];
        uint256 distance = haversine(coordinate);

        if (distance >= winner.shortestDistance)
            revert playerCooridinateTooFar();
        winner.shortestDistance = distance;
        winner.closestCoordinate = coordinate;
        winner.latestWinner = player;

        emit winnerUpdated(
            winner.latestWinner,
            winner.shortestDistance,
            winner.closestCoordinate
        );
    }

    // The goal is to return haversine(_coordinate, treasure.treasureCoordinate);
    function haversine(
        Coordinate memory _coordinate
    ) internal view returns (uint256) {
        uint256 dx = (_coordinate.x - treasure.treasureCoordinate.x) ** 2;
        uint256 dy = (_coordinate.y - treasure.treasureCoordinate.y) ** 2;
        return dx * dy;
    }

    function withdrawReward() external payable {
        if (!winner.winnerDeclared) revert winnerNotDeclared();
        if (msg.sender != winner.latestWinner) revert playerNotWinner();
        (bool success, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        require(success, "withdraw call has failed");
    }
}
