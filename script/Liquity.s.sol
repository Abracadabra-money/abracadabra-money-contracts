// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "utils/BaseScript.sol";
import "utils/CauldronLib.sol";
import "oracles/ProxyOracle.sol";
import "oracles/InverseOracle.sol";
import "swappers/ZeroXTokenSwapper.sol";
import "swappers/ZeroXTokenLevSwapper.sol";
import "strategies/LiquityStabilityPoolStrategy.sol";

contract LiquityScript is BaseScript {
    function run()
        public
        returns (
            LiquityStabilityPoolStrategy strategy
        )
    {
        address xMerlin = constants.getAddress("xMerlin");
        IBentoBoxV1 degenBox = IBentoBoxV1(constants.getAddress("mainnet.degenBox"));

        vm.startBroadcast();

        strategy = new LiquityStabilityPoolStrategy(
            IERC20(constants.getAddress("mainnet.liquity.lusd")),
            degenBox,
            ILiquityStabilityPool(constants.getAddress("mainnet.liquity.stabilityPool"))
        );

        strategy.setRewardTokenEnabled(IERC20(address(0)), true);
        strategy.setRewardTokenEnabled(IERC20(constants.getAddress("mainnet.liquity.lqty")), true);
        strategy.setSwapper(constants.getAddress("mainnet.aggregators.zeroXExchangProxy"));

        if (!testing) {
            strategy.setStrategyExecutor(xMerlin, true);
            strategy.setFeeParameters(xMerlin, 10);
            strategy.transferOwnership(xMerlin, true, false);
        } else {
            strategy.setStrategyExecutor(deployer(), true);
        }

        vm.stopBroadcast();
    }
}
