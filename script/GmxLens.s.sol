// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "interfaces/IGmxVault.sol";
import "interfaces/IGmxGlpManager.sol";
import "lenses/GmxLens.sol";

contract GmxLensScript is BaseScript {
    function run() public {
        startBroadcast();

        if (block.chainid == ChainId.Arbitrum) {
            new GmxLens(
                IGmxGlpManager(constants.getAddress("arbitrum.gmx.glpManager")),
                IGmxVault(constants.getAddress("arbitrum.gmx.vault"))
            );
        }
        stopBroadcast();
    }
}
