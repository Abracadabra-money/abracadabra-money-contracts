// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "utils/BaseScript.sol";
import "cauldrons/CauldronV4.sol";
import "periphery/DegenBoxOwner.sol";
import "utils/CauldronLib.sol";
import "oracles/ProxyOracle.sol";
import "periphery/CauldronOwner.sol";
import "interfaces/IGmxRewardRouterV2.sol";
import "tokens/GmxGlpWrapper.sol";
import "periphery/GmxGlpRewardHandler.sol";
import "periphery/MimCauldronDistributor.sol";
import "periphery/DegenBoxTokenWrapper.sol";
import "periphery/GlpWrapperHarvestor.sol";

contract GlpCauldronScript is BaseScript {
    function run()
        public
        returns (
            ICauldronV4 cauldron,
            GmxGlpWrapper wrapper,
            MimCauldronDistributor mimDistributor,
            GlpWrapperHarvestor harvestor
        )
    {
        vm.startBroadcast();

        /*
        GmxGlpRewardHandler	
        0xf4b36812d1645dca9d562846e3abf416d590349e 

        GLP Cauldron	
        0x6f0334e9d2cc1ac63a563e5b63cf172e3ab9ba7f 

        GlpWrapperHarvestor	
        0x635693f0d3ff2eeb95d19e680ed5fbecc5e7d3be 

        DegenBoxTokenWrapper	
        0xd3a238d0e0f47aac26defd2afcf03ea41da263c7 

        MimCauldronDistributor	
        0x9620a2a6a6c6dcef83fcab71430aaad55e7c0999 

        Abra GlpWrapper	
        0xd8cbd5b22d7d37c978609e4e394ce8b9c003993b 

        CauldronV4 MasterContract	
        0xe05811aff7a105fe05b7144f4e0dd777a83a194e 

        CauldronOwner	
        0xaf2fbb9cb80edfb7d3f2d170a65ae3bfa42d0b86 

        DegenBoxOwner	
        0x0d2a5107435cbbbe21db1adb5f1e078e63e59449 
        */
        if (block.chainid == ChainId.Arbitrum) {
            DegenBoxOwner degenBoxOwner = new DegenBoxOwner(IBentoBoxV1(constants.getAddress("arbitrum.degenBox")));

            IGmxRewardRouterV2 rewardRouterV2 = IGmxRewardRouterV2(constants.getAddress("arbitrum.gmx.rewardRouterV2"));
            CauldronOwner cauldronOwner = new CauldronOwner(
                constants.getAddress("arbitrum.safe.ops"),
                ERC20(address(IERC20(constants.getAddress("arbitrum.mim"))))
            );

            CauldronV4 masterContract = new CauldronV4(
                IBentoBoxV1(constants.getAddress("arbitrum.degenBox")),
                IERC20(constants.getAddress("arbitrum.mim"))
            );

            wrapper = new GmxGlpWrapper(
                IERC20(constants.getAddress("arbitrum.gmx.sGLP")),
                "abra wrapped sGlp",
                "abra-wsGlp",
                address(IBentoBoxV1(constants.getAddress("arbitrum.degenBox")))
            );
            GmxGlpRewardHandler rewardHandler = new GmxGlpRewardHandler();

            // owner is only from the sGlp wrapper
            rewardHandler.transferOwnership(address(0), true, true);

            wrapper.setRewardHandler(address(rewardHandler));

            cauldron = CauldronLib.deployCauldronV4(
                IBentoBoxV1(constants.getAddress("arbitrum.degenBox")),
                address(masterContract),
                wrapper,
                ProxyOracle(0x0E1eA2269D6e22DfEEbce7b0A4c6c3d415b5bC85),
                "",
                7500, // 75% ltv
                0, // 0% interests
                0, // 0% opening
                750 // 7.5% liquidation
            );

            cauldron.setBlacklistedCallee(address(degenBoxOwner), true);
            mimDistributor = new MimCauldronDistributor(ERC20(address(IERC20(constants.getAddress("arbitrum.mim")))), cauldron);

            // Periphery contract used to atomically wrap and deposit to degenbox
            new DegenBoxTokenWrapper(IBentoBoxV1(constants.getAddress("arbitrum.degenBox")), wrapper);

            // Use to facilitate collecting and swapping rewards to the distributor & distribute
            harvestor = new GlpWrapperHarvestor(
                IERC20(constants.getAddress("arbitrum.weth")),
                IERC20(constants.getAddress("arbitrum.mim")),
                rewardRouterV2,
                GmxGlpRewardHandler(address(wrapper)),
                mimDistributor
            );

            wrapper.setStrategyExecutor(address(harvestor), true);
            GmxGlpRewardHandler(address(wrapper)).setFeeParameters(constants.getAddress("arbitrum.safe.ops"), 0);
            GmxGlpRewardHandler(address(wrapper)).setSwapper(constants.getAddress("arbitrum.aggregators.zeroXExchangProxy"));
            GmxGlpRewardHandler(address(wrapper)).setRewardRouter(rewardRouterV2);
            GmxGlpRewardHandler(address(wrapper)).setRewardTokenEnabled(IERC20(constants.getAddress("arbitrum.weth")), true);
            GmxGlpRewardHandler(address(wrapper)).setRewardTokenEnabled(IERC20(constants.getAddress("arbitrum.gmx.gmx")), true);
            GmxGlpRewardHandler(address(wrapper)).setSwappingTokenOutEnabled(IERC20(constants.getAddress("arbitrum.mim")), true);
            GmxGlpRewardHandler(address(wrapper)).setAllowedSwappingRecipient(address(mimDistributor), true);

            // Only when deploying live
            if (!testing) {
                cauldronOwner.setOperator(constants.getAddress("arbitrum.safe.ops"), true);
                masterContract.setFeeTo(constants.getAddress("arbitrum.safe.ops"));

                cauldronOwner.transferOwnership(constants.getAddress("arbitrum.safe.ops"), true, false);
                masterContract.transferOwnership(address(cauldronOwner), true, false);
                degenBoxOwner.transferOwnership(constants.getAddress("arbitrum.safe.ops"), true, false);
                wrapper.transferOwnership(constants.getAddress("arbitrum.safe.ops"), true, false);
            }
        } else {
            revert("chain not supported");
        }

        vm.stopBroadcast();
    }
}
