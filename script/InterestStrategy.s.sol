// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "utils/BaseScript.sol";
import "strategies/InterestStrategy.sol";
import "utils/CauldronLib.sol";

contract InterestStrategyScript is BaseScript {
    function run() public returns (InterestStrategy fttStrat) {
        address xMerlin = constants.getAddress("xMerlin");

        vm.startBroadcast();

        uint64 rate = CauldronLib.getInterestPerSecond(100); // 1%
        uint64 finalRate = CauldronLib.getInterestPerSecond(1300); // 13%
        uint64 duration = 30 days;

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

        fttStrat.setSwapper(constants.getAddress("mainnet.aggregators.zeroXExchangProxy"));
        fttStrat.changeInterestRate(rate, finalRate, duration);

        wbtcStrat.setSwapper(constants.getAddress("mainnet.aggregators.zeroXExchangProxy"));
        wbtcStrat.changeInterestRate(rate, finalRate, duration);

        wethStrat.setSwapper(constants.getAddress("mainnet.aggregators.zeroXExchangProxy"));
        wbtcStrat.changeInterestRate(rate, finalRate, duration);

        if (!testing) {
            fttStrat.transferOwnership(xMerlin, true, false);
            wbtcStrat.transferOwnership(xMerlin, true, false);
            wethStrat.transferOwnership(xMerlin, true, false);
        }

        vm.stopBroadcast();
    }
}
