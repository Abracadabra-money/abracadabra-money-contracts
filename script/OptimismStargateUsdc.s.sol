// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "forge-std/Script.sol";
import "utils/BaseScript.sol";
import "utils/CauldronScript.sol";
import "utils/StargateScript.sol";

contract OptimismStargateUsdcScript is BaseScript, CauldronScript, StargateScript {
    function run()
        public
        returns (
            ICauldronV3 cauldron,
            ISwapperV2 swapper,
            ILevSwapperV2 levSwapper,
            StargateLPStrategy strategy
        )
    {
        address mim = constants.getAddress("optimism.mim");
        address xMerlin = constants.getAddress("xMerlin");
        address collateral = constants.getAddress("optimism.stargate.usdcPool");
        address degenBox = constants.getAddress("optimism.degenBox");
        address masterContract = constants.getAddress("optimism.cauldronV3");

        vm.startBroadcast();

        ProxyOracle oracle = deployStargateLpOracle(collateral, constants.getAddress("optimism.chainlink.usdc"), "Stargate USDC LP");

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

        (swapper, levSwapper) = deployStargateZeroExSwappers(
            address(degenBox),
            collateral,
            1,
            constants.getAddress("optimism.stargate.router"),
            mim,
            constants.getAddress("optimism.aggregators.zeroXExchangProxy")
        );

        strategy = deployStargateLPStrategy(
            collateral,
            address(degenBox),
            constants.getAddress("optimism.stargate.router"),
            constants.getAddress("optimism.stargate.staking"),
            constants.getAddress("optimism.op"),
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
