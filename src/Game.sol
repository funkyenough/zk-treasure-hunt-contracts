// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

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

    mapping(address => bool) public hasActiveDeposit;
    mapping(address => Coordinate[]) public playerCoordinates;

    ClosestPlayer public closestPlayer;

    bytes32 public immutable treasureHash;
    Coordinate public treasureCoordinate;

    struct Coordinate {
        uint256 x;
        uint256 y;
    }

    struct ClosestPlayer {
        address playerAddress;
        uint256 distance;
        Coordinate coordinate;
    }

    enum GamePhase {
        REGISTRATION,
        ACTIVE,
        RESOLUTION,
        COMPLETED
    }

    event DepositReceived(address indexed player);
    event DepositWithdrawn(address indexed player);
    event RewardWithdrawn(address indexed player);

    event ClosestPlayerUpdated(
        address indexed player,
        uint256 indexed distance,
        Coordinate indexed coordinate
    );

    error DepositAmountIncorrect(uint256);
    error DepositWithdrawFailed();

    error NotInPhase(GamePhase);
    error notInResolutionPhaseOrCompletion();

    error playerAlreadyRegistered();
    error playerHasNoActiveDeposit();
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
        treasureHash = _treasureHash;

        closestPlayer = ClosestPlayer({
            playerAddress: address(0),
            distance: type(uint256).max,
            coordinate: Coordinate({x: 0, y: 0}) // This is also really bad.
        });
    }

    modifier onlyInPhase(GamePhase phase) {
        if (getCurrentPhase() != phase) revert NotInPhase(phase);
        _;
    }

    modifier onlyRegistered() {
        if (!hasActiveDeposit[msg.sender]) revert playerHasNoActiveDeposit();
        _;
    }

    function getCurrentPhase() public view returns (GamePhase) {
        if (block.timestamp < registrationEndTime)
            return GamePhase.REGISTRATION;
        if (block.timestamp < gameEndTime) return GamePhase.ACTIVE;
        if (block.timestamp < resolutionEndTime) return GamePhase.RESOLUTION;
        return GamePhase.COMPLETED;
    }

    function getWinner()
        public
        view
        onlyInPhase(GamePhase.COMPLETED)
        returns (address)
    {
        if (closestPlayer.playerAddress == address(0)) revert noLatestWinner();
        return closestPlayer.playerAddress;
    }

    // Player should be allowed to deposit again during registration phase if they choose to withdraw their deposit.
    function deposit() external payable onlyInPhase(GamePhase.REGISTRATION) {
        GamePhase currentPhase = getCurrentPhase();
        if (currentPhase != GamePhase.REGISTRATION)
            revert NotInPhase(currentPhase);
        if (msg.value != registrationFee)
            revert DepositAmountIncorrect(msg.value);
        if (hasActiveDeposit[msg.sender]) revert playerAlreadyRegistered();

        hasActiveDeposit[msg.sender] = true;
        emit DepositReceived(msg.sender);
    }

    // Player should be allowed to withdraw deposit during registration phase.
    // Player should also be allowed to withdraw during completed phase if no closest player exists.
    function withdrawDeposit() external {
        if (!hasActiveDeposit[msg.sender]) revert playerHasNoActiveDeposit();
        GamePhase currentPhase = getCurrentPhase();
        if (
            currentPhase != GamePhase.REGISTRATION &&
            !(currentPhase == GamePhase.COMPLETED &&
                closestPlayer.playerAddress == address(0))
        ) {
            revert NotInPhase(currentPhase);
        }

        hasActiveDeposit[msg.sender] = false;
        (bool success, ) = msg.sender.call{value: registrationFee}("");
        if (!success) revert DepositWithdrawFailed();
        emit DepositWithdrawn(msg.sender);
    }

    // The difficult part is to make this function only callable by the mobile client while still remaining permissionless...
    function addPlayerCoordinate(
        uint256 _x,
        uint256 _y
    ) external onlyInPhase(GamePhase.ACTIVE) onlyRegistered {
        playerCoordinates[msg.sender].push(Coordinate(_x, _y));
    }

    function revealTreasureCoordinate(uint256 _x, uint256 _y) external {
        GamePhase gamePhase = getCurrentPhase();
        if (
            gamePhase != GamePhase.RESOLUTION ||
            gamePhase != GamePhase.COMPLETED
        ) revert notInResolutionPhaseOrCompletion();
        if (!verifyTreasureCoordinate(_x, _y))
            revert InvalidTreasureCoordinate();
        treasureCoordinate.x = _x;
        treasureCoordinate.y = _y;
    }

    // Using keccak for now
    function verifyTreasureCoordinate(
        uint256 _x,
        uint256 _y
    ) internal view returns (bool) {
        bytes32 _treasureHash = keccak256(abi.encodePacked(_x, _y));
        return (treasureHash == _treasureHash);
    }

    // Anyone can call this function to update the winner
    function updateWinner(address player, uint256 coordinateId) external {
        if (!hasActiveDeposit[player]) revert playerAlreadyRegistered();
        Coordinate memory coordinate = playerCoordinates[player][coordinateId];
        uint256 distance = haversine(coordinate);

        if (distance >= closestPlayer.distance)
            revert playerCooridinateTooFar();
        closestPlayer.distance = distance;
        closestPlayer.coordinate = coordinate;
        closestPlayer.playerAddress = player;

        emit ClosestPlayerUpdated(
            closestPlayer.playerAddress,
            closestPlayer.distance,
            closestPlayer.coordinate
        );
    }

    // The goal is to return haversine(_coordinate, treasure.treasureCoordinate);
    function haversine(
        Coordinate memory _coordinate
    ) internal view returns (uint256) {
        uint256 dx = (_coordinate.x - treasureCoordinate.x) ** 2;
        uint256 dy = (_coordinate.y - treasureCoordinate.y) ** 2;
        return dx * dy;
    }

    function withdrawReward()
        external
        payable
        onlyInPhase(GamePhase.COMPLETED)
    {
        if (msg.sender != closestPlayer.playerAddress) revert playerNotWinner();
        (bool success, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        require(success, "withdraw call has failed");
        emit RewardWithdrawn(msg.sender);
    }
}
