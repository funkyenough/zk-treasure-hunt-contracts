//SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Game} from "../../src/Game.sol";

contract GameHarness is Game {
  constructor(
    string memory name,
    string memory description,
    uint256 registrationEndTime,
    uint256 gameEndTime,
    uint256 resolutionEndTime,
    uint256 registrationFee,
    bytes32 treasureHash
  )
    Game(
      name,
      description,
      registrationEndTime,
      gameEndTime,
      resolutionEndTime,
      registrationFee,
      treasureHash
    )
  {}

  function exposed_verifyTreasureCoordinate(int64 _x, int64 _y) external view returns (bool) {
    return verifyTreasureCoordinate(_x, _y);
  }

  function exposed_haversine(int64 _x, int64 _y) external view returns (uint256) {
    return haversine(_x, _y);
  }
}
