// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "utils/BaseScript.sol";
import "utils/DegenBoxScript.sol";
import "utils/CauldronScript.sol";
import "utils/SolidlyLikeScript.sol";
import "utils/WithdrawerScript.sol";
import "utils/VelodromeScript.sol";

contract VelodromeVolatileOpUsdcScript is BaseScript, DegenBoxScript, CauldronScript, SolidlyLikeScript, WithdrawerScript, VelodromeScript {
    function run()
        public
        returns (
            ICauldronV3 cauldron,
            ISwapperV2 swapper,
            ILevSwapperV2 levSwapper,
            SolidlyGaugeVolatileLPStrategy strategy
        )
    {
        address xMerlin = constants.getAddress("xMerlin");
        address masterContract = constants.getAddress("optimism.cauldronV3");
        IERC20 mim = IERC20(constants.getAddress("optimism.mim"));
        IBentoBoxV1 degenBox = IBentoBoxV1(constants.getAddress("optimism.degenBox"));
        ISolidlyPair pair = ISolidlyPair(constants.getAddress("optimism.velodrome.vOpUsdc"));

        vm.startBroadcast();

        SolidlyLpWrapper collateral = deployWrappedLp(
            pair,
            ISolidlyRouter(constants.getAddress("optimism.velodrome.router")),
            IVelodromePairFactory(constants.getAddress("optimism.velodrome.factory"))
        );

        IOracle oracle = deploySolidlyLikeVolatileLPOracle(
            "Abracadabra Velodrome vOP/USDC",
            collateral,
            IAggregator(constants.getAddress("optimism.chainlink.op")),
            IAggregator(constants.getAddress("optimism.chainlink.usdc"))
        );

        cauldron = deployCauldronV3(
            address(degenBox),
            address(masterContract),
            IERC20(address(collateral)),
            oracle, // vOP/USDC Wrapper LP Oracle
            "",
            7000, // 70% ltv
            200, // 2% interests
            0, // 0% opening
            900 // 9% liquidation
        );

        (swapper, levSwapper) = deploySolidlyLikeVolatileZeroExSwappers(
            degenBox,
            ISolidlyRouter(constants.getAddress("optimism.velodrome.router")),
            collateral,
            mim,
            constants.getAddress("optimism.aggregators.zeroXExchangProxy")
        );

        strategy = deploySolidlyGaugeVolatileLPStrategy(
            collateral,
            degenBox,
            ISolidlyRouter(constants.getAddress("optimism.velodrome.router")),
            ISolidlyGauge(constants.getAddress("optimism.velodrome.vOpUsdcGauge")),
            constants.getAddress("optimism.velodrome.velo"),
            constants.getPairCodeHash("optimism.velodrome"),
            false // Swap Velo rewards to USDC to provide vOP/USDC liquidity
        );

        if (!testing) {
            collateral.setFeeParameters(xMerlin, 10);
            collateral.setStrategyExecutor(xMerlin, true);

            strategy.setStrategyExecutor(xMerlin, true);
            strategy.setFeeParameters(xMerlin, 10);
            strategy.transferOwnership(xMerlin, true, false);
        } else {
            strategy.setStrategyExecutor(deployer(), true);
            collateral.setFeeParameters(deployer(), 10);
            collateral.setStrategyExecutor(deployer(), true);
        }

        vm.stopBroadcast();
    }
}
