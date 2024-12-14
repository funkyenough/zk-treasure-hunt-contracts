//SPDX-License-Identifier:MIT

pragma solidity ^0.8.26;

contract DeployInput {
    string constant NAME = "GameTest";
    string constant DESCRIPTION = "A test for Game contract";
    uint256 constant RESOLUTION_DURATION = 1 hours;
    uint256 constant REGISTRATION_FEE = 1 gwei;
    bytes32 constant TREASURE = keccak256(abi.encodePacked(uint256(0), uint256(0)));
}