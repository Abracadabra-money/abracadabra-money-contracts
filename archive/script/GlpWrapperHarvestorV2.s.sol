// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "utils/BaseScript.sol";
import "periphery/GlpWrapperHarvestor.sol";
import "periphery/GmxGlpRewardHandler.sol";
import "periphery/MimCauldronDistributor.sol";

contract GlpWrapperHarvestorV2Script is BaseScript {
    function run() public {
        address safe = constants.getAddress("arbitrum.safe.ops");

        address mim = constants.getAddress("arbitrum.mim");
        address weth = constants.getAddress("arbitrum.weth");
        address rewardRouterV2 = constants.getAddress("arbitrum.gmx.rewardRouterV2");

        vm.startBroadcast();

        GlpWrapperHarvestor harvestorV2 = new GlpWrapperHarvestor(
            IERC20(weth),
            IERC20(mim),
            IGmxRewardRouterV2(rewardRouterV2),
            GmxGlpRewardHandler(0x3477Df28ce70Cecf61fFfa7a95be4BEC3B3c7e75),
            MimCauldronDistributor(0x5BE2c1C8c0045594a4aAa244e237840F94d95A15)
        );

        // wrapper.setStrategyExecutor(0x8E534c5D52C921dBd6dEbc56503cF0e2DCe6d534, false);
        // wrapper.setStrategyExecutor(0xf9cE23237B25E81963b500781FA15d6D38A0DE62, true);

        harvestorV2.transferOwnership(safe, true, false);

        vm.stopBroadcast();
    }
}
