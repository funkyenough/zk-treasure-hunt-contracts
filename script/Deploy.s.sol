// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {DeployInput} from "script/DeployInput.sol";
import {Game} from "src/Game.sol";

contract Deploy is DeployInput, Script {
    uint256 deployerPrivateKey;

    function run() public returns (Game) {
        deployerPrivateKey = vm.envOr(
            "FOUNDRY_DEPLOYER_PRIVATE_KEY",
            uint256(
                0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
            )
        );
        vm.startBroadcast(deployerPrivateKey);
        Game _game = new Game(
            NAME,
            DESCRIPTION,
            block.timestamp + 1 hours,
            block.timestamp + 2 hours,
            RESOLUTION_DURATION,
            REGISTRATION_FEE,
            TREASURE
        );
        vm.stopBroadcast();

        return Game(_game);
    }
}
