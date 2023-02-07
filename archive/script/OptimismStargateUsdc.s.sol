// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "forge-std/Script.sol";
import "utils/BaseScript.sol";
import "utils/CauldronDeployLib.sol";
import "utils/StargateLib.sol";

contract OptimismStargateUsdcScript is BaseScript {
    function run()
        public
        returns (
            ICauldronV3 cauldron,
            ISwapperV2 swapper,
            ILevSwapperV2 levSwapper,
            StargateLPStrategy strategy
        )
    {
        address xMerlin = constants.getAddress("xMerlin");
        address masterContract = constants.getAddress("optimism.cauldronV3_2");
        IERC20 mim = IERC20(constants.getAddress("optimism.mim"));
        IStargatePool collateral = IStargatePool(constants.getAddress("optimism.stargate.usdcPool"));
        IBentoBoxV1 degenBox = IBentoBoxV1(constants.getAddress("optimism.degenBox"));

        vm.startBroadcast();

        ProxyOracle oracle = StargateLib.deployLpOracle(
            collateral,
            IAggregator(constants.getAddress("optimism.chainlink.usdc")),
            "Stargate USDC LP"
        );

        cauldron = CauldronDeployLib.deployCauldronV3(
            degenBox,
            address(masterContract),
            IERC20(address(collateral)),
            IOracle(oracle),
            "",
            9500, // 95% ltv
            0, // 0% interests
            0, // 0% opening
            50 // 0.5% liquidation
        );

        (swapper, levSwapper) = StargateLib.deployZeroExSwappers(
            degenBox,
            collateral,
            1,
            IStargateRouter(constants.getAddress("optimism.stargate.router")),
            mim,
            constants.getAddress("optimism.aggregators.zeroXExchangProxy")
        );

        strategy = StargateLib.deployLPStrategy(
            collateral,
            degenBox,
            IStargateRouter(constants.getAddress("optimism.stargate.router")),
            IStargateLPStaking(constants.getAddress("optimism.stargate.staking")),
            IERC20(constants.getAddress("optimism.op")),
            0
        );

        strategy.setStargateSwapper(constants.getAddress("optimism.aggregators.zeroXExchangProxy"));

        if (!testing) {
            strategy.setStrategyExecutor(xMerlin, true);
            strategy.setFeeParameters(xMerlin, 10);
            strategy.transferOwnership(xMerlin, true, false);
            oracle.transferOwnership(xMerlin, true, false);
        } else {
            strategy.setStrategyExecutor(deployer(), true);
        }

        vm.stopBroadcast();
    }
}
