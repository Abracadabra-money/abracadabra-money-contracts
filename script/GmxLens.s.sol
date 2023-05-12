// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/LegacyBaseScript.sol";
import "lenses/GmxLens.sol";

contract GmxLensScript is LegacyBaseScript {
    function run() public returns (GmxLens lens) {
        if (block.chainid == ChainId.Arbitrum) {
            startBroadcast();

            lens = new GmxLens(
                IGmxGlpManager(constants.getAddress("arbitrum.gmx.glpManager")),
                IGmxVault(constants.getAddress("arbitrum.gmx.vault"))
            );

            stopBroadcast();
        } else {
            revert("chain not supported");
        }
    }
}
