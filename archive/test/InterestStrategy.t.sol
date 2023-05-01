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
        (strategy) = script.deploy();

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

        assertEq(strategy.getYearlyInterestBips(), 100);
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
        vm.startPrank(deployer);

        vm.expectEmit(true, false, false, true);
        emit LogStrategyLoss(address(fttToken), 95230653273009744834); // report a loss of ≈95 ftt
        strategy.safeHarvest(type(uint256).max, false, 0, false);
        pendingFeeEarned = strategy.pendingFeeEarned();

        // ≈95 ftt in fee
        assertApproxEqAbs(pendingFeeEarned, 95 ether, 1 ether);

        // available amount should be ≈3478204 (3478299 - 95)
        // 95 of which is locked so that we can collect it as interest
        uint256 available = strategy.availableAmount();
        console2.log(">> Available Amount After 1 day:", available);
        assertApproxEqAbs(available, 3478204 ether, 1 ether);

        // At this point, interest should be 1.4%
        assertEq(strategy.getYearlyInterestBips(), 140);
        advanceTime(1 days);
        vm.expectEmit(true, false, false, true);
        emit LogStrategyLoss(address(fttToken), 133322914822633711973); // report a loss of ≈133 ftt
        strategy.safeHarvest(type(uint256).max, false, 0, false);
        pendingFeeEarned = strategy.pendingFeeEarned();
        assertApproxEqAbs(pendingFeeEarned, 228 ether, 1 ether); // 95 + 133 fee
        available = strategy.availableAmount();

        console2.log(">> Available Amount After 2 day:", available);
        assertApproxEqAbs(available, 3478071 ether, 1 ether);

        // interest got ramped up after the last harvest
        assertEq(strategy.getYearlyInterestBips(), 180);

        // after more than 30 days, the interest should now be 13%
        // but since the interest are ramped up during the harvest it should be 1.8% still
        // and then 13% for now one. IRL harvest should be called frequently to rampup the interests
        // more smoothly.
        advanceTime(30 days);

        assertEq(strategy.getYearlyInterestBips(), 180);
        vm.expectEmit(true, false, false, true);
        emit LogStrategyLoss(address(fttToken), 5142455282151977778180); // report a loss of ≈5142 ftt (1.8% for 30 days)
        strategy.safeHarvest(type(uint256).max, false, 0, false);

        available = strategy.availableAmount();
        console2.log(">> Available Amount After 32 day:", available);

        assertEq(strategy.getYearlyInterestBips(), 1300);
        (, , , uint64 duration) = strategy.interestLerp();
        assertEq(duration, 0);

        advanceTime(1 days);
        vm.expectEmit(true, false, false, true);
        emit LogStrategyLoss(address(fttToken), 1237998492549126682851); // report a loss of ≈1236 ftt (13% for 1 days)
        strategy.safeHarvest(type(uint256).max, false, 0, false);
        assertEq(strategy.getYearlyInterestBips(), 1300);
        available = strategy.availableAmount();

        console2.log(">> Available Amount After 33 day:", available);
        pendingFeeEarned = strategy.pendingFeeEarned();

        // nothing to harvest here
        strategy.safeHarvest(type(uint256).max, false, 0, false);
        assertEq(strategy.pendingFeeEarned(), pendingFeeEarned);
        strategy.safeHarvest(type(uint256).max, false, 0, false);
        assertEq(strategy.pendingFeeEarned(), pendingFeeEarned);
        assertEq(strategy.getYearlyInterestBips(), 1300);

        {
            // now try to withdraw fees. Available should stay the same but ftt balance lowered
            uint256 balanceBefore = fttToken.balanceOf(address(strategy));
            assertEq(strategy.availableAmount(), available);
            strategy.withdrawFees();
            strategy.withdrawFees();
            assertEq(fttToken.balanceOf(address(strategy)), balanceBefore - pendingFeeEarned);
            assertEq(strategy.availableAmount(), available);
            assertEq(strategy.pendingFeeEarned(), 0);
        }

        // advance 1 days, change interest and see if pending fees are kept in memory for the next harvest
        advanceTime(1 days);
        available = strategy.availableAmount();
        assertEq(strategy.pendingFeeEarnedAdjustement(), 0);
        strategy.setInterestPerSecond(CauldronLib.getInterestPerSecond(100)); // 1%

        // pending fees were 0 but setInterestPerSecond should have called accrue
        // and should now be the same as pendingFeeEarnedAdjustement (unharvested loss)
        pendingFeeEarned = strategy.pendingFeeEarned();
        assertEq(pendingFeeEarned, strategy.pendingFeeEarnedAdjustement());

        assertEq(strategy.getYearlyInterestBips(), 100);

        // should have 1 day of accrued interest at 13%
        assertApproxEqAbs(strategy.availableAmount(), available - 1237 ether, 1 ether);
        console2.log(">> Available Amount After 34 day:", strategy.availableAmount());
        assertApproxEqAbs(strategy.pendingFeeEarnedAdjustement(), 1237 ether, 1 ether);

        // don't advance time but run harvest, shouldn't add any interest but report loss stored in pendingFeeEarnedAdjustement
        vm.expectEmit(true, false, false, true);
        emit LogStrategyLoss(address(fttToken), strategy.pendingFeeEarnedAdjustement());
        strategy.safeHarvest(type(uint256).max, false, 0, false);
        vm.stopPrank();

        // divest
        vm.startPrank(bentoBox.owner());
        bentoBox.setStrategyTargetPercentage(fttToken, 20);
        vm.stopPrank();

        vm.startPrank(deployer);
        vm.expectEmit(true, false, false, false);
        emit LogStrategyDivest(address(fttToken), 2080702162733679540996427);
        strategy.safeHarvest(type(uint256).max, true, 0, false);
        vm.stopPrank();

        // prepare strategy exit
        vm.startPrank(bentoBox.owner());
        vm.expectEmit(true, true, false, false);
        emit LogStrategyQueued(address(fttToken), address(0));
        bentoBox.setStrategy(fttToken, IStrategy(address(0)));

        // no changes in pending fees yet.
        assertEq(strategy.pendingFeeEarned(), pendingFeeEarned);
        uint256 fttInBentoBoxBefore = fttToken.balanceOf(address(bentoBox));
        uint256 fttInStrategyBefore = fttToken.balanceOf(address(strategy));
        advanceTime(1210000);

        // now exit the strategy
        bentoBox.setStrategy(fttToken, IStrategy(address(0)));

        // should have collected 1210000 seconds of interests on 1389750 ftt
        assertApproxEqAbs(strategy.pendingFeeEarned(), pendingFeeEarned + 532 ether, 1 ether);

        // should have the remaining balance to withdraw the fee
        assertEq(fttToken.balanceOf(address(strategy)), strategy.pendingFeeEarned());
        assertEq(strategy.availableAmount(), 0);

        // should have returned back the ftt amount minus what needs to be left in the contract to withdraw fees
        assertEq(fttToken.balanceOf(address(bentoBox)), fttInBentoBoxBefore + fttInStrategyBefore - strategy.pendingFeeEarned());
        vm.stopPrank();

        console2.log("balance to swap", fttToken.balanceOf(address(strategy)));
        vm.startPrank(deployer);
        // withdraw the remaining fees swapping to MIM
        // https://api.0x.org/swap/v1/quote?buyToken=0x99D8a9C45b2ecA8864373A26D1459e3Dff1e17F3&sellToken=0x50D1c9771902476076eCFc8B2A83Ad6b9355a4c9&sellAmount=1770864754943694261787&slippagePercentage=1
        uint256 amountOut = strategy.swapAndwithdrawFees(
            0,
            IERC20(constants.getAddress("mainnet.mim")),
            hex"0f3b31b20000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000005fffaf702d7e10ce1b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000300000000000000000000000050d1c9771902476076ecfc8b2a83ad6b9355a4c9000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000099d8a9c45b2eca8864373a26d1459e3dff1e17f30000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000001400000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000200000000000000000000000050d1c9771902476076ecfc8b2a83ad6b9355a4c9000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000042c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20001f4a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480001f499d8a9c45b2eca8864373a26d1459e3dff1e17f3000000000000000000000000000000000000000000000000000000000000869584cd000000000000000000000000100000000000000000000000000000000000001100000000000000000000000000000000000000000000009b478ebcd763598941"
        );

        assertApproxEqAbs(amountOut, 36_000 ether, 1000 ether);
        assertEq(strategy.availableAmount(), 0);
        assertEq(strategy.pendingFeeEarned(), 0);
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
