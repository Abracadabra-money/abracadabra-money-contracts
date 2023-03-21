// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "utils/BaseScript.sol";
import "strategies/InterestStrategy.sol";
import "utils/CauldronDeployLib.sol";

contract InterestStrategyScript is BaseScript {
    function run() public returns (InterestStrategy fttStrat) {
        address xMerlin = constants.getAddress("xMerlin");

        vm.startBroadcast();

        uint64 rate = CauldronLib.getInterestPerSecond(100); // 1%

        fttStrat = new InterestStrategy(
            IERC20(constants.getAddress("mainnet.ftt")),
            IERC20(constants.getAddress("mainnet.mim")),
            IBentoBoxV1(constants.getAddress("mainnet.sushiBentoBox")),
            constants.getAddress("mainnet.multiSig")
        );
        InterestStrategy wbtcStrat = new InterestStrategy(
            IERC20(constants.getAddress("mainnet.wbtc")),
            IERC20(constants.getAddress("mainnet.mim")),
            IBentoBoxV1(constants.getAddress("mainnet.degenBox")),
            constants.getAddress("mainnet.multiSig")
        );
        InterestStrategy wethStrat = new InterestStrategy(
            IERC20(constants.getAddress("mainnet.weth")),
            IERC20(constants.getAddress("mainnet.mim")),
            IBentoBoxV1(constants.getAddress("mainnet.degenBox")),
            constants.getAddress("mainnet.multiSig")
        );

        fttStrat.setSwapper(constants.getAddress("mainnet.aggregators.zeroXExchangeProxy"));
        wbtcStrat.setSwapper(constants.getAddress("mainnet.aggregators.zeroXExchangeProxy"));
        wethStrat.setSwapper(constants.getAddress("mainnet.aggregators.zeroXExchangeProxy"));
        fttStrat.setInterestPerSecond(rate);
        wbtcStrat.setInterestPerSecond(rate);
        wethStrat.setInterestPerSecond(rate);

        if (!testing) {
            fttStrat.setStrategyExecutor(constants.getAddress("mainnet.devOps"), true);
            wbtcStrat.setStrategyExecutor(constants.getAddress("mainnet.devOps"), true);
            wethStrat.setStrategyExecutor(constants.getAddress("mainnet.devOps"), true);

            fttStrat.transferOwnership(xMerlin, true, false);
            wbtcStrat.transferOwnership(xMerlin, true, false);
            wethStrat.transferOwnership(xMerlin, true, false);
        } else {
            fttStrat.setStrategyExecutor(deployer(), true);
            wbtcStrat.setStrategyExecutor(deployer(), true);
            wethStrat.setStrategyExecutor(deployer(), true);
        }

        vm.stopBroadcast();
    }
}
