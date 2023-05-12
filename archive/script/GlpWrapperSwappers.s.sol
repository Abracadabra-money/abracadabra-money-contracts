// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "interfaces/IGmxRewardRouterV2.sol";
import "interfaces/IGmxVault.sol";
import "interfaces/IGmxGlpRewardRouter.sol";
import "tokens/GmxGlpWrapper.sol";
import "swappers/GLPWrapperSwapper.sol";
import "swappers/GLPWrapperLevSwapper.sol";

contract GlpWrapperSwappersScript is BaseScript {
    function deploy() public {
        if (block.chainid == ChainId.Arbitrum) {
            address sGlp = constants.getAddress("arbitrum.gmx.sGLP");
            address degenBox = constants.getAddress("arbitrum.degenBox");
            address mim = constants.getAddress("arbitrum.mim");
            address glpRewardRouter = constants.getAddress("arbitrum.gmx.glpRewardRouter");
            address swapper = constants.getAddress("arbitrum.aggregators.zeroXExchangeProxy");
            address glpManager = constants.getAddress("arbitrum.gmx.glpManager");
            address vault = constants.getAddress("arbitrum.gmx.vault");
            GmxGlpWrapper wrapper = GmxGlpWrapper(constants.getAddress("arbitrum.abracadabraWrappedStakedGlp"));

            startBroadcast();

            new GLPWrapperSwapper(
                IBentoBoxV1(degenBox),
                IGmxVault(vault),
                wrapper,
                IERC20(mim),
                IERC20(sGlp),
                IGmxRewardRouterV2(glpRewardRouter),
                swapper
            );

            new GLPWrapperLevSwapper(
                IBentoBoxV1(degenBox),
                IGmxVault(vault),
                wrapper,
                IERC20(mim),
                IERC20(sGlp),
                glpManager,
                IGmxGlpRewardRouter(glpRewardRouter),
                swapper
            );

            stopBroadcast();
        } else {
            revert("chain not supported");
        }
    }
}
