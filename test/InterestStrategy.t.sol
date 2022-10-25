// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "BoringSolidity/ERC20.sol";
import "utils/BaseTest.sol";
import "script/InterestStrategy.s.sol";

contract MyTest is BaseTest {
    event LogStrategyProfit(address indexed token, uint256 amount);
    event LogStrategyDivest(address indexed token, uint256 amount);
    event LogStrategyQueued(address indexed token, address indexed strategy);
    event LogStrategyLoss(address indexed token, uint256 amount);

    InterestStrategy strategy;
    IBentoBoxV1 bentoBox;
    ERC20 fttToken;

    function setUp() public override {
        forkMainnet(15819653);
        super.setUp();

        InterestStrategyScript script = new InterestStrategyScript();
        script.setTesting(true);
        (strategy) = script.run();

        bentoBox = IBentoBoxV1(constants.getAddress("mainnet.sushiBentoBox"));
        fttToken = ERC20(constants.getAddress("mainnet.ftt"));
    }

    function testInterestBuildUp() public {
        // Interest should go from 1% to 13% over a period of 30 days
        (uint256 yearlyInterestRateBips, uint256 maxYearlyInterestRateBips, uint256 increasePerSecondPpm) = strategy.parameters();
        assertEq(yearlyInterestRateBips, 100);
        assertEq(maxYearlyInterestRateBips, 1300);

        // increasePerSecondPpm / 1e6 = 0.000046% increase per-second
        assertEq(increasePerSecondPpm, 46);

        _activateStrategy();
    }

    function _activateStrategy() private {
        vm.startPrank(bentoBox.owner());
        bentoBox.setStrategy(fttToken, strategy);
        advanceTime(1210000);
        bentoBox.setStrategy(fttToken, strategy);
        bentoBox.setStrategyTargetPercentage(fttToken, 50);
        vm.stopPrank();

        vm.startPrank(deployer);
        strategy.safeHarvest(type(uint256).max, true, 0, false);
        assertGt(fttToken.balanceOf(address(strategy)), 0);

        (, , , , uint256 pendingFeeEarned) = strategy.accrueInfo();

        assertEq(pendingFeeEarned, 0);
        vm.stopPrank();
    }
}
