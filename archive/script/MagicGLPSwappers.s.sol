// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "interfaces/IGmxVault.sol";
import "interfaces/IGmxGlpManager.sol";
import "swappers/MagicGlpSwapper.sol";
import "swappers/MagicGlpLevSwapper.sol";
import "lenses/GmxLens.sol";

contract MagicGLPSwappersScript is BaseScript {
    function run()
        public
        returns (
            GmxLens lens,
            MagicGlpSwapper swapper,
            MagicGlpLevSwapper levSwapper
        )
    {
        startBroadcast();

        if (block.chainid == ChainId.Arbitrum) {
            address sGlp = constants.getAddress("arbitrum.gmx.sGLP");
            address degenBox = constants.getAddress("arbitrum.degenBox");
            address glpManager = constants.getAddress("arbitrum.gmx.glpManager");
            address glpRewardRouter = constants.getAddress("arbitrum.gmx.glpRewardRouter");
            address vault = constants.getAddress("arbitrum.gmx.vault");

            IERC20 magicGlp = IERC20(constants.getAddress("arbitrum.magicGlp"));

            lens = new GmxLens(
                IGmxGlpManager(constants.getAddress("arbitrum.gmx.glpManager")),
                IGmxVault(constants.getAddress("arbitrum.gmx.vault"))
            );
           
        }
        stopBroadcast();
    }
}
