// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "utils/BaseScript.sol";
import "utils/DegenBoxLib.sol";
import "utils/CauldronDeployLib.sol";
import "utils/SolidlyLikeLib.sol";
import "utils/VelodromeLib.sol";

contract VelodromeVolatileOpUsdcScript is BaseScript {
    enum Deployment {
        INITIAL,
        VELODROME_SWAPPERS
    }

    Deployment deployment = Deployment.INITIAL;

    function run()
        public
        returns (
            ICauldronV3 cauldron,
            ISwapperV2 swapper,
            ILevSwapperV2 levSwapper,
            SolidlyGaugeVolatileLPStrategy strategy
        )
    {
        if (deployment == Deployment.INITIAL) {
            return _deployInitial();
        } else if (deployment == Deployment.VELODROME_SWAPPERS) {
            _deploySwappers();
        }
    }

    function _deployInitial()
        public
        returns (
            ICauldronV3 cauldron,
            ISwapperV2 swapper,
            ILevSwapperV2 levSwapper,
            SolidlyGaugeVolatileLPStrategy strategy
        )
    {
        address safe = constants.getAddress("optimism.safe.ops");
        address masterContract = constants.getAddress("optimism.cauldronV3_2");
        IERC20 mim = IERC20(constants.getAddress("optimism.mim"));
        IBentoBoxV1 degenBox = IBentoBoxV1(constants.getAddress("optimism.degenBox"));
        ISolidlyPair pair = ISolidlyPair(constants.getAddress("optimism.velodrome.vOpUsdc"));

        startBroadcast();

        SolidlyLpWrapper collateral = VelodromeLib.deployWrappedLp(
            pair,
            ISolidlyRouter(constants.getAddress("optimism.velodrome.router")),
            IVelodromePairFactory(constants.getAddress("optimism.velodrome.factory"))
        );

        ProxyOracle oracle = SolidlyLikeLib.deployVolatileLPOracle(
            "Abracadabra Velodrome vOP/USDC",
            collateral,
            IAggregator(constants.getAddress("optimism.chainlink.op")),
            IAggregator(constants.getAddress("optimism.chainlink.usdc"))
        );

        cauldron = CauldronDeployLib.deployCauldronV3(
            degenBox,
            address(masterContract),
            IERC20(address(collateral)),
            oracle, // vOP/USDC Wrapper LP Oracle
            "",
            7000, // 70% ltv
            200, // 2% interests
            0, // 0% opening
            800 // 8% liquidation
        );

        (swapper, levSwapper) = SolidlyLikeLib.deployVolatileZeroExSwappers(
            degenBox,
            ISolidlyRouter(constants.getAddress("optimism.velodrome.router")),
            collateral,
            mim,
            constants.getAddress("optimism.aggregators.zeroXExchangProxy")
        );

        strategy = SolidlyLikeLib.deployVolatileLPStrategy(
            collateral,
            degenBox,
            ISolidlyRouter(constants.getAddress("optimism.velodrome.router")),
            ISolidlyGauge(constants.getAddress("optimism.velodrome.vOpUsdcGauge")),
            constants.getAddress("optimism.velodrome.velo"),
            constants.getPairCodeHash("optimism.velodrome"),
            false // Swap Velo rewards to USDC to provide vOP/USDC liquidity
        );

        if (!testing) {
            collateral.setFeeParameters(safe, 10);
            collateral.setStrategyExecutor(safe, true);

            strategy.setStrategyExecutor(safe, true);
            strategy.setFeeParameters(safe, 10);
            strategy.transferOwnership(safe, true, false);

            collateral.transferOwnership(safe, true, false);
            oracle.transferOwnership(safe, true, false);
        } else {
            strategy.setStrategyExecutor(deployer(), true);
            collateral.setFeeParameters(deployer(), 10);
            collateral.setStrategyExecutor(deployer(), true);
        }

        stopBroadcast();
    }

    function _deploySwappers() public {
        IERC20 mim = IERC20(constants.getAddress("optimism.mim"));
        IBentoBoxV1 degenBox = IBentoBoxV1(constants.getAddress("optimism.degenBox"));

        startBroadcast();

        VelodromeLib.deployVolatileLpSwappers(
            degenBox,
            ISolidlyRouter(constants.getAddress("optimism.velodrome.router")),
            ISolidlyLpWrapper(constants.getAddress("optimism.abraWrappedVOpUsdc")),
            mim,
            IVelodromePairFactory(constants.getAddress("optimism.velodrome.factory")),
            false // MIM -> USDC -> OP/USDC
        );

        stopBroadcast();
    }
}
