// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "utils/BaseScript.sol";
import "strategies/SpookySwapLPStrategy.sol";

contract SpookySwapStrategyV2 is BaseScript {
    function deploy() public returns (SpookySwapLPStrategy strategy) {
        address xMerlin = constants.getAddress("xMerlin");

        vm.startBroadcast();
        strategy = new SpookySwapLPStrategy(
            IERC20(constants.getAddress("fantom.spookyswap.wFtmMim")),
            IBentoBoxV1(constants.getAddress("fantom.degenBox")),
            constants.getAddress("fantom.spookyswap.factory"),
            IMasterChef(constants.getAddress("fantom.spookyswap.farmV2")),
            19, // wFTM/MIM farmV2 pid
            IUniswapV2Router01(constants.getAddress("fantom.spookyswap.router")),
            constants.getPairCodeHash("fantom.spookyswap")
        );

        // BOO -> FTM -> wFTM/MIM
        strategy.setRewardTokenInfo(constants.getAddress("fantom.spookyswap.boo"), true, true);

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
