// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title A ZK Treasure Hunt Game
 *  @author funkyenough, kota
 */
contract Game {
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
    error PlayerHasActiveDeposit();
    error PlayerHasNoActiveDeposit();
    error NoClosestPlayer();
    error PlayerNotClosestPlayer();
    error PlayerCoordinateTooFar();
    error WinnerNotDeclared();
    error InvalidTreasureCoordinate();

    /**
     * @notice Represents a geographic coordinate as integers
     * @dev Coordinates are stored as fixed-point integers with specific precision:
     * - Format: XXX.YYYYYYYYYYY (3 digits.9 decimal places)
     * - Example: 12.345678901 -> 12345678901
     * - Range: Valid GPS coordinates (-90 to +90 for latitude, -180 to +180 for longitude)
     * - Precision: 9 decimal places (~1.1mm spatial resolution at the equator)
     * - Storage: Each coordinate uses int64 for efficient storage while maintaining precision
     */
    struct Coordinate {
        int64 x;
        int64 y;
    }

    struct ClosestPlayer {
        address playerAddress;
        uint256 distance;
        Coordinate coordinate;
    }

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

    enum GamePhase {
        REGISTRATION,
        ACTIVE,
        RESOLUTION,
        COMPLETED
    }

    modifier onlyInPhase(GamePhase phase) {
        if (getCurrentPhase() != phase) revert NotInPhase(phase);
        _;
    }

    modifier onlyRegistered() {
        if (!hasActiveDeposit[msg.sender]) revert PlayerHasNoActiveDeposit();
        _;
    }

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

    // Player should be allowed to deposit again during registration phase if they choose to withdraw
    // their deposit.
    function deposit() external payable onlyInPhase(GamePhase.REGISTRATION) {
        GamePhase currentPhase = getCurrentPhase();
        if (currentPhase != GamePhase.REGISTRATION)
            revert NotInPhase(currentPhase);
        if (msg.value != registrationFee)
            revert DepositAmountIncorrect(msg.value);
        if (hasActiveDeposit[msg.sender]) revert PlayerHasActiveDeposit();

        hasActiveDeposit[msg.sender] = true;
        emit DepositReceived(msg.sender);
    }

    // Player should be allowed to withdraw deposit during registration phase.
    // Player should also be allowed to withdraw during completed phase if no closest player exists.
    function withdrawDeposit() external {
        if (!hasActiveDeposit[msg.sender]) revert PlayerHasNoActiveDeposit();
        GamePhase currentPhase = getCurrentPhase();
        if (
            currentPhase != GamePhase.REGISTRATION &&
            !(currentPhase == GamePhase.COMPLETED &&
                closestPlayer.playerAddress == address(0))
        ) revert NotInPhase(currentPhase);

        hasActiveDeposit[msg.sender] = false;
        (bool success, ) = msg.sender.call{value: registrationFee}("");
        if (!success) revert DepositWithdrawFailed();
        emit DepositWithdrawn(msg.sender);
    }

    function withdrawReward() external onlyInPhase(GamePhase.COMPLETED) {
        if (msg.sender != closestPlayer.playerAddress) revert PlayerNotClosestPlayer();
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "withdraw call has failed");
        emit RewardWithdrawn(msg.sender);
    }

    // The difficult part is to make this function only callable by the mobile client while still
    // remaining permissionless...
    function addPlayerCoordinate(
        int64 _x,
        int64 _y
    ) external onlyInPhase(GamePhase.ACTIVE) onlyRegistered {
        playerCoordinates[msg.sender].push(Coordinate(_x, _y));
    }

    function revealTreasureCoordinate(int64 _x, int64 _y) external {
        GamePhase currentPhase = getCurrentPhase();
        if (
            currentPhase != GamePhase.RESOLUTION ||
            currentPhase != GamePhase.COMPLETED
        ) {
            revert NotInPhase(currentPhase);
        }
        if (!verifyTreasureCoordinate(_x, _y))
            revert InvalidTreasureCoordinate();
        treasureCoordinate.x = _x;
        treasureCoordinate.y = _y;
    }

    // Anyone can call this function to update the closestPlayer
    function updateClosestPlayer(
        address player,
        uint256 coordinateId
    ) external {
        if (!hasActiveDeposit[player]) revert PlayerHasActiveDeposit();
        Coordinate memory coordinate = playerCoordinates[player][coordinateId];
        uint256 distance = haversine(coordinate.x, coordinate.y);

        if (distance >= closestPlayer.distance) revert PlayerCoordinateTooFar();
        closestPlayer.distance = distance;
        closestPlayer.coordinate = coordinate;
        closestPlayer.playerAddress = player;

        emit ClosestPlayerUpdated(
            closestPlayer.playerAddress,
            closestPlayer.distance,
            closestPlayer.coordinate
        );
    }

    function getCurrentPhase() public view returns (GamePhase) {
        if (block.timestamp < registrationEndTime)
            return GamePhase.REGISTRATION;
        if (block.timestamp < gameEndTime) return GamePhase.ACTIVE;
        if (block.timestamp < resolutionEndTime) return GamePhase.RESOLUTION;
        return GamePhase.COMPLETED;
    }

    function getClosestPlayer() public view returns (address) {
        if (closestPlayer.playerAddress == address(0)) revert NoClosestPlayer();
        return closestPlayer.playerAddress;
    }

    // Using keccak for now
    function verifyTreasureCoordinate(
        int64 _x,
        int64 _y
    ) internal view returns (bool) {
        bytes32 _treasureHash = keccak256(abi.encodePacked(_x, _y));
        return (treasureHash == _treasureHash);
    }

    // The goal is to return haversine(_coordinate, treasure.treasureCoordinate);
    function haversine(int64 _x, int64 _y) internal view returns (uint256) {
        int256 dx = int256(_x - treasureCoordinate.x);
        int256 dy = int256(_y - treasureCoordinate.y);
        return uint256(dx * dx) + uint256(dy * dy);
    }
}
