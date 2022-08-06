// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "utils/BaseScript.sol";
import "strategies/SolidlyGaugeVolatileLPStrategy.sol";

contract VelodromeVolatileOpUsdcScript is BaseScript {
    function run()
        public
        returns (
            ICauldronV3 cauldron,
            IBentoBoxV1 degenBox,
            ISwapperV2 swapper,
            ILevSwapperV2 levSwapper,
            SolidlyGaugeVolatileLPStrategy strategy
        )
    {
        address mim = constants.getAddress("optimism.mim");
        address xMerlin = constants.getAddress("xMerlin");
        address collateral = constants.getAddress("optimism.velodrome.vOpUsdc");

        vm.startBroadcast();

        degenBox = deployDegenBox(constants.getAddress("optimism.weth"));
        ICauldronV3 masterContract = deployCauldronV3MasterContract(address(degenBox), mim);
        degenBox.whitelistMasterContract(address(masterContract), true);
        cauldron = deployCauldronV3(
            address(degenBox),
            address(masterContract),
            collateral,
            0x04146736FEF83A25e39834a972cf6A5C011ACEad, // vOP/USDC LP Oracle
            "",
            7000, // 70% ltv
            200, // 2% interests
            0, // 0% opening
            900 // 8% liquidation
        );

        (swapper, levSwapper) = deploySolidlyLikeVolatileZeroExSwappers(
            address(degenBox),
            constants.getAddress("optimism.velodrome.router"),
            collateral,
            mim,
            constants.getAddress("optimism.aggregators.zeroXExchangProxy")
        );

        strategy = new SolidlyGaugeVolatileLPStrategy(
            ERC20(collateral),
            degenBox,
            ISolidlyRouter(constants.getAddress("optimism.velodrome.router")),
            ISolidlyGauge(constants.getAddress("optimism.velodrome.vOpUsdcGauge")),
            constants.getAddress("optimism.velodrome.velo"),
            constants.getPairCodeHash("optimism.velodrome"),
            false // Swap Velo rewards to USDC to provide vOP/USDC liquidity
        );

        logDeployed("Strategy", address(strategy));
        
        if (!testing) {
            strategy.setStrategyExecutor(xMerlin, true);
            strategy.setFeeParameters(xMerlin, 10);

            degenBox.transferOwnership(xMerlin, true, false);
            strategy.transferOwnership(xMerlin, true, false);
        } else {
            strategy.setStrategyExecutor(deployer(), true);
        }

        vm.stopBroadcast();
    }
}
