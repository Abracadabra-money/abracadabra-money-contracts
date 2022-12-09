// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "utils/BaseScript.sol";
import "cauldrons/CauldronV4.sol";
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
        /*
            GmxGlpRewardHandler (Proxy user in GlpWrapper)
             0x8D99A15a2Be434431cf16d98e23F7fAfE0d0da30
             feeCollector: ops
             feePercent: 0
             swapper: 0x aggregator
             gmx rewardRouter: 0xA906F338CB21815cBc4Bc87ace9e68c87eF8d8F1
             rewardTokenEnabled: [weth, gmx]
             swappingTokenOutEnabled: [mim]
             allowedSwappingRecipient: MimCauldronDistributor

            GLP Cauldron
             0xE09223bBdb85a20111DCD72299142a8626d5eA4b
             parameters: 75% ltv 0% interests 0% opening 7.5% liquidation
             blacklisted callee: [degenBox, cauldron, DegenBoxOwner]

            GlpWrapperHarvestor (Used For Gelato Offchain Resolver)
             0x8E534c5D52C921dBd6dEbc56503cF0e2DCe6d534
             use current contract addresses

            DegenBoxTokenWrapper
             0xDd45c6614305D705a444B3baB0405D68aC85DbA5
             wrapper: Abra GlpWrapper
             allowance maxed to degenbox

            MimCauldronDistributor
             0xc5c01568a3B5d8c203964049615401Aaf0783191
             cauldron: GLP Cauldron

            Abra GlpWrapper 
                0x3477Df28ce70Cecf61fFfa7a95be4BEC3B3c7e75
                rewardHandler: GmxGlpRewardHandler
                strategyExecutor: [GlpWrapperHarvestor]
                staked GLP: 0x5402B5F40310bDED796c7D0F3FF6683f5C0cFfdf
                owner: ops

            CauldronV4 MasterContract
                0xe05811aff7a105fe05b7144f4e0dd777a83a194e
                feeTo: ops
                owner: CauldronOwner

            CauldronOwner
                0xaf2fbb9cb80edfb7d3f2d170a65ae3bfa42d0b86
                treasury: ops
                operators: [ops]
                owner: ops

            DegenBoxOwner
                0x0d2a5107435cbbbe21db1adb5f1e078e63e59449
                owner: ops
                Optional DegenBoxOwner (support dynamic rebalancing, not used for GLP Cauldron)
                If used, need to blacklistCallee its address in GLP Cauldron
        */
        if (block.chainid == ChainId.Arbitrum) {
            address safe = constants.getAddress("arbitrum.safe.ops");
            address sGlp = constants.getAddress("arbitrum.gmx.sGLP");
            address degenBox = constants.getAddress("arbitrum.degenBox");
            address masterContract = constants.getAddress("arbitrum.cauldronV4");
            address mim = constants.getAddress("arbitrum.mim");
            address weth = constants.getAddress("arbitrum.weth");
            address rewardRouterV2 = constants.getAddress("arbitrum.gmx.rewardRouterV2");
            address gmx = constants.getAddress("arbitrum.gmx.gmx");
            address swapper = constants.getAddress("arbitrum.aggregators.zeroXExchangProxy");

            vm.startBroadcast();
            wrapper = new GmxGlpWrapper(IERC20(sGlp), "AbracadabraWrappedStakedGlp", "abra-wsGlp");

            cauldron = CauldronLib.deployCauldronV4(
                IBentoBoxV1(degenBox),
                masterContract,
                wrapper,
                ProxyOracle(0x0E1eA2269D6e22DfEEbce7b0A4c6c3d415b5bC85),
                "",
                7500, // 75% ltv
                0, // 0% interests
                0, // 0% opening
                750 // 7.5% liquidation
            );

            mimDistributor = new MimCauldronDistributor(ERC20(mim), cauldron);

            // Periphery contract used to atomically wrap and deposit to degenbox
            new DegenBoxTokenWrapper(IBentoBoxV1(degenBox), wrapper);

            // Use to facilitate collecting and swapping rewards to the distributor & distribute
            harvestor = new GlpWrapperHarvestor(
                IERC20(weth),
                IERC20(mim),
                IGmxRewardRouterV2(rewardRouterV2),
                GmxGlpRewardHandler(address(wrapper)),
                mimDistributor
            );

            GmxGlpRewardHandler rewardHandler = new GmxGlpRewardHandler();
            rewardHandler.transferOwnership(address(0), true, true); // owner is only from the sGlp wrapper
            wrapper.setRewardHandler(address(rewardHandler));
            wrapper.setStrategyExecutor(address(harvestor), true);

            GmxGlpRewardHandler(address(wrapper)).setFeeParameters(safe, 0);
            GmxGlpRewardHandler(address(wrapper)).setSwapper(swapper);
            GmxGlpRewardHandler(address(wrapper)).setRewardRouter(IGmxRewardRouterV2(rewardRouterV2));
            GmxGlpRewardHandler(address(wrapper)).setRewardTokenEnabled(IERC20(weth), true);
            GmxGlpRewardHandler(address(wrapper)).setRewardTokenEnabled(IERC20(gmx), true);
            GmxGlpRewardHandler(address(wrapper)).setSwappingTokenOutEnabled(IERC20(mim), true);
            GmxGlpRewardHandler(address(wrapper)).setAllowedSwappingRecipient(address(mimDistributor), true);

            // Only when deploying live
            if (!testing) {
                wrapper.transferOwnership(safe, true, false);
                harvestor.transferOwnership(safe, true, false);
            }

            vm.stopBroadcast();
        } else {
            revert("chain not supported");
        }
    }
}
