// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "utils/BaseScript.sol";
import "periphery/DegenBoxOwner.sol";

contract DegenBoxOwnerScript is BaseScript {
    function deploy()
        public
    {
        vm.startBroadcast();

        if (block.chainid == ChainId.Arbitrum) {
            DegenBoxOwner degenBoxOwner = new DegenBoxOwner(IBentoBoxV1(constants.getAddress("arbitrum.degenBox")));

            // Only when deploying live
            if (!testing) {
                degenBoxOwner.transferOwnership(constants.getAddress("arbitrum.safe.ops"), true, false);
            }
        } else {
            revert("chain not supported");
        }

        vm.stopBroadcast();
    }
}
