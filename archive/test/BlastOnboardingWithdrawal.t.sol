// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import {BlastOnboarding} from "/blast/BlastOnboarding.sol";
import {BlastOnboardingLockedWithdrawer} from "/blast/BlastOnboardingBoot.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

contract BlastOnboardingWithdrawalTest is BaseTest {
    using SafeTransferLib for address;

    BlastOnboarding constant onboarding = BlastOnboarding(payable(0xa64B73699Cc7334810E382A4C09CAEc53636Ab96));
    BlastOnboardingLockedWithdrawer withdrawer;

    function setUp() public override {
        fork(ChainId.Blast, 845780);
        super.setUp();

        withdrawer = new BlastOnboardingLockedWithdrawer();

        pushPrank(onboarding.owner());
        onboarding.setBootstrapper(address(withdrawer));
        withdrawer = BlastOnboardingLockedWithdrawer(address(onboarding));
        popPrank();
    }

    uint256 userUnlockedBefore;
    uint256 userLockedBefore;
    uint256 userTotalBefore;
    uint256 totalUnlockedBefore;
    uint256 totalLockedBefore;
    uint256 totalBefore;
    uint256 userUnlockedAfter;
    uint256 userLockedAfter;
    uint256 userTotalAfter;
    uint256 totalUnlockedAfter;
    uint256 totalLockedAfter;
    uint256 totalAfter;

    function testWithdrawMIM() public {
        address user = 0xfB3485c2e209A5cfBDC1447674256578f1A80eE3;
        address mim = 0x76DA31D7C9CbEAE102aff34D3398bC450c8374c1;

        _withdraw(user, mim, 1000 ether);
    }

    function testWithdrawUSDB() public {
        address user = 0xfB3485c2e209A5cfBDC1447674256578f1A80eE3;
        address usdb = 0x4300000000000000000000000000000000000003;

        _withdraw(user, usdb, 36036331675075760164);

        vm.expectRevert();
        withdrawer.withdrawLocked(usdb, 1);
    }

    function _withdraw(address user, address token, uint amountToWithdraw) private {
        (userUnlockedBefore, userLockedBefore, userTotalBefore) = onboarding.balances(user, token);
        (totalUnlockedBefore, totalLockedBefore, totalBefore) = onboarding.totals(token);

        uint256 balanceTokenBefore = token.balanceOf(address(onboarding));

        //uint beforeClosing = vm.snapshot();
        //// Simulate closing the LLE
        //{
        //    pushPrank(onboarding.owner());
        //    onboarding.close();
        //    popPrank();

        //    pushPrank(user);
        //    vm.expectRevert(abi.encodeWithSignature("ErrWrongState()"));
        //    withdrawer.withdrawLocked(token, 1000);
        //    popPrank();

        //    pushPrank(onboarding.owner());
        //    vm.expectRevert(abi.encodeWithSignature("ErrWrongState()"));
        //    onboarding.open();
        //    popPrank();
        //}
        // Back to LLE in opened state
        //vm.revertTo(beforeClosing);

        pushPrank(user);
        vm.expectRevert(abi.encodeWithSignature("ErrUnsupportedToken()"));
        withdrawer.withdrawLocked(0x4300000000000000000000000000000000000004, amountToWithdraw);
        popPrank();

        pushPrank(user);
        vm.expectRevert(abi.encodeWithSignature("ErrUnsupportedToken()"));
        withdrawer.withdrawLocked(0x4300000000000000000000000000000000000004, amountToWithdraw);
        withdrawer.withdrawLocked(token, amountToWithdraw / 2);
        withdrawer.withdrawLocked(token, amountToWithdraw / 2);

        popPrank();

        (userUnlockedAfter, userLockedAfter, userTotalAfter) = onboarding.balances(user, token);
        (totalUnlockedAfter, totalLockedAfter, totalAfter) = onboarding.totals(token);

        assertEq(userUnlockedAfter, userUnlockedBefore);
        assertEq(userLockedAfter, userLockedBefore - amountToWithdraw);
        assertEq(userTotalAfter, userTotalBefore - amountToWithdraw);
        assertEq(totalUnlockedAfter, totalUnlockedBefore);
        assertEq(totalLockedAfter, totalLockedBefore - amountToWithdraw);
        assertEq(totalAfter, totalBefore - amountToWithdraw);
        assertEq(token.balanceOf(address(onboarding)), balanceTokenBefore - amountToWithdraw);
    }
}
