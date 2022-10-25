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
        (uint256 yearlyInterestRateBips, uint256 maxYearlyInterestRateBips, uint256 increasePerSecondE7) = strategy.parameters();
        assertEq(yearlyInterestRateBips, 100);
        assertEq(maxYearlyInterestRateBips, 1300);

        // increasePerSecondE7 / 1e7 = 0.000046% increase per-second
        assertEq(increasePerSecondE7, 46);

        _activateStrategy();
    }

    function testInterests() public {
        _activateStrategy();

        (, , , , uint256 pendingFeeEarned) = strategy.accrueInfo();
        assertEq(pendingFeeEarned, 0);
    
        // advance 1 day and accrue interest at 1% apr
        // ftt balance is ≈3478299 giving ≈95 ftt in interest
        advanceTime(1 days);
        strategy.accrue();

        uint256 balance = fttToken.balanceOf(address(strategy));
        console2.log("balance", balance);
        (, , , , pendingFeeEarned) = strategy.accrueInfo();

        // ≈95 ftt in fee
        assertApproxEqAbs(pendingFeeEarned, 95 ether, 1 ether);

        // available amount should be ≈3478204 (3478299 - 95)
        // 95 of which is locked so that we can collect it as interest
        uint available = strategy.availableAmount();
        assertApproxEqAbs(available, 3478204 ether, 1 ether);

        // rebalancing should report a loss
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
