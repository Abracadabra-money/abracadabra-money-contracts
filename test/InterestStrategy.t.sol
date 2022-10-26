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
        _activateStrategy();

        vm.startPrank(deployer);
        strategy.setInterestPerSecondWithLerp(CauldronLib.getInterestPerSecond(100), CauldronLib.getInterestPerSecond(1300), 30 days);
        vm.stopPrank();

        // Interest should go from 1% to 13% over a period of 30 days
        (, uint64 startInterestPerSecond, uint64 targetInterestPerSecond, uint64 duration) = strategy.interestLerp();
        assertEq(CauldronLib.getInterestPerYearFromInterestPerSecond(strategy.interestPerSecond()), 100);
        assertEq(CauldronLib.getInterestPerYearFromInterestPerSecond(startInterestPerSecond), 100);
        assertEq(CauldronLib.getInterestPerYearFromInterestPerSecond(targetInterestPerSecond), 1300);
        assertEq(duration, 30 days);
    }

    function testInterests() public {
        _activateStrategy();

        vm.startPrank(deployer);
        strategy.setInterestPerSecondWithLerp(CauldronLib.getInterestPerSecond(100), CauldronLib.getInterestPerSecond(1300), 30 days);
        vm.stopPrank();
        
        uint128 pendingFeeEarned = strategy.pendingFeeEarned();
        assertEq(pendingFeeEarned, 0);

        // advance 1 day and accrue interest at 1% apr
        // ftt balance is ≈3478299 giving ≈95 ftt in interest
        advanceTime(1 days);
        vm.prank(deployer);
        strategy.safeHarvest(type(uint256).max, false, 0, false);
        pendingFeeEarned = strategy.pendingFeeEarned();

        // ≈95 ftt in fee
        assertApproxEqAbs(pendingFeeEarned, 95 ether, 1 ether);

        // available amount should be ≈3478204 (3478299 - 95)
        // 95 of which is locked so that we can collect it as interest
        uint256 available = strategy.availableAmount();
        assertApproxEqAbs(available, 3478204 ether, 1 ether);

        // harvest with rebalancing should report a loss
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

        uint128 pendingFeeEarned = strategy.pendingFeeEarned();

        assertEq(pendingFeeEarned, 0);
        vm.stopPrank();
    }
}
