// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "forge-std/Script.sol";
import "utils/BaseScript.sol";

contract OptimismStargateUsdcScript is BaseScript {
    function run()
        public
        returns (
            ICauldronV3 cauldron,
            ISwapperV2 swapper,
            ILevSwapperV2 levSwapper,
            SolidlyGaugeVolatileLPStrategy strategy
        )
    {
        address mim = constants.getAddress("optimism.mim");
        address xMerlin = constants.getAddress("xMerlin");
        address collateral = constants.getAddress("optimism.velodrome.vOpUsdc");
        address degenBox = constants.getAddress("optimism.degenBox");
        address masterContract = constants.getAddress("optimism.cauldronV3");

        vm.startBroadcast();

        ProxyOracle oracle = deployStargateLpOracle(
            constants.getAddress("optimism.stargate.usdcPool"),
            constants.getAddress("optimism.chainlink.usdc"),
            "Stargate USDC LP"
        );

        cauldron = deployCauldronV3(
            address(degenBox),
            address(masterContract),
            collateral,
            address(oracle),
            "",
            9500, // 95% ltv
            0, // 0% interests
            0, // 0% opening
            50 // 0.5% liquidation
        );

        /*(swapper, levSwapper) = deploySolidlyLikeVolatileZeroExSwappers(
            address(degenBox),
            constants.getAddress("optimism.velodrome.router"),
            collateral,
            mim,
            constants.getAddress("optimism.aggregators.zeroXExchangProxy")
        );

        strategy = deploySolidlyGaugeVolatileLPStrategy(
            collateral,
            address(degenBox),
            constants.getAddress("optimism.velodrome.router"),
            constants.getAddress("optimism.velodrome.vOpUsdcGauge"),
            constants.getAddress("optimism.velodrome.velo"),
            constants.getPairCodeHash("optimism.velodrome"),
            false // Swap Velo rewards to USDC to provide vOP/USDC liquidity
        );

        MultichainWithdrawer withdrawer = deployMultichainWithdrawer(
            address(0),
            address(degenBox),
            mim,
            constants.getAddress("optimism.bridges.anyswapRouter"),
            constants.getAddress("optimism.abraMultiSig")
        );

        if (!testing) {
            strategy.setStrategyExecutor(xMerlin, true);
            strategy.setFeeParameters(xMerlin, 10);
            degenBox.transferOwnership(xMerlin, true, false);
            strategy.transferOwnership(xMerlin, true, false);
            withdrawer.transferOwnership(xMerlin, true, false);
        } else {
            strategy.setStrategyExecutor(deployer(), true);
        }*/

        vm.stopBroadcast();
    }
}
