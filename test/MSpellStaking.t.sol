// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/MSpellStaking.s.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {IRewardHandler} from "/staking/MSpellStaking.sol";

contract RewardHandler is IRewardHandler {
    using SafeTransferLib for address;

    function notifyRewards(address _user, address _token, uint256 _amount, bytes memory _data) external payable override {
        if (_data.length > 0 && msg.value == 0) {
            revert("RewardHandler: invalid msg.value");
        }
        _token.safeTransfer(_user, _amount);
    }
}

contract MSpellStakingTest is BaseTest {
    using SafeTransferLib for address;

    MSpellStaking staking;
    address mim;
    address spell;

    function setUp() public override {
        fork(ChainId.Mainnet, 20215675);
        super.setUp();

        MSpellStakingScript script = new MSpellStakingScript();
        script.setTesting(true);
        mim = toolkit.getAddress(block.chainid, "mim");
        spell = toolkit.getAddress(block.chainid, "spell");

        (staking) = script.deploy();
    }

    function testLockupPeriod() public {
        uint256 depositAmount = 1000 * 1e18;

        deal(address(spell), alice, depositAmount);
        pushPrank(alice);
        spell.safeApprove(address(staking), depositAmount);
        staking.deposit(depositAmount);
        vm.expectRevert(abi.encodeWithSignature("ErrLockedUp()"));
        staking.withdraw(depositAmount);
        popPrank();

        advanceTime(1 days + 1);

        pushPrank(alice);
        staking.withdraw(depositAmount);
        (uint128 amount, , ) = staking.userInfo(alice);
        assertEq(amount, 0, "Withdraw after lockup did not work as expected");
        popPrank();
    }

    function testDeposit() public {
        uint256 depositAmount = 1000 * 1e18;

        deal(address(spell), alice, depositAmount);
        pushPrank(alice);
        spell.safeApprove(address(staking), depositAmount);
        staking.deposit(depositAmount);
        popPrank();

        (uint128 amount, , ) = staking.userInfo(alice);
        assertEq(amount, depositAmount, "Deposit amount does not match");
    }

    function testWithdraw() public {
        uint256 depositAmount = 1000 * 1e18;

        deal(address(spell), alice, depositAmount);
        pushPrank(alice);
        spell.safeApprove(address(staking), depositAmount);
        staking.deposit(depositAmount);

        advanceTime(1 days + 1);
        staking.withdraw(depositAmount / 2);
        (uint128 amount, , ) = staking.userInfo(alice);
        assertEq(amount, depositAmount / 2, "Withdraw amount does not match");
        popPrank();
    }

    function testClaimRewards() public {
        uint256 depositAmount = 1000 * 1e18;
        uint256 rewardAmount = 500 * 1e18;

        deal(address(spell), alice, depositAmount);
        pushPrank(alice);
        spell.safeApprove(address(staking), depositAmount);
        staking.deposit(depositAmount);
        popPrank();

        _distributeRewards(rewardAmount);

        pushPrank(alice);
        uint256 pending = staking.pendingReward(alice);
        advanceTime(1 days + 1);
        staking.withdraw(0); // Withdraw 0 just to claim rewards
        popPrank();

        assertGt(pending, 0, "Pending rewards should be greater than zero");
        assertEq(mim.balanceOf(alice), pending, "Reward balance mismatch");
    }

    function testTwoUsersRewardDistribution() public {
        uint256 depositAmountUser1 = 1000 * 1e18;
        uint256 depositAmountUser2 = 2000 * 1e18;
        uint256 totalRewardAmount = 900 * 1e18;

        deal(address(spell), alice, depositAmountUser1);
        deal(address(spell), bob, depositAmountUser2);

        pushPrank(alice);
        spell.safeApprove(address(staking), depositAmountUser1);
        staking.deposit(depositAmountUser1);
        popPrank();

        advanceTime(1 hours);

        pushPrank(bob);
        spell.safeApprove(address(staking), depositAmountUser2);
        staking.deposit(depositAmountUser2);
        popPrank();

        _distributeRewards(totalRewardAmount);

        advanceTime(1 days + 1);

        pushPrank(alice);
        uint256 pendingRewardUser1 = staking.pendingReward(alice);
        staking.withdraw(0);
        popPrank();

        uint256 pendingRewardUser2 = staking.pendingReward(bob);

        assertEq(mim.balanceOf(alice), pendingRewardUser1, "alice reward balance mismatch");
        pendingRewardUser1 = staking.pendingReward(alice);
        assertEq(pendingRewardUser1, 0, "alice should not have pending rewards");

        assertGt(pendingRewardUser2, 0, "bob should have pending rewards");
        assertEq(mim.balanceOf(bob), 0, "bob should not have claimed rewards yet");

        pushPrank(bob);
        staking.withdraw(0);
        popPrank();

        assertEq(mim.balanceOf(bob), pendingRewardUser2, "bobreward balance mismatch after claiming");
        pendingRewardUser2 = staking.pendingReward(bob);
        assertEq(pendingRewardUser2, 0, "bob should not have pending rewards");

        uint256 totalDistributedRewards = mim.balanceOf(alice) + mim.balanceOf(bob);
        assertEq(totalDistributedRewards, totalRewardAmount, "Total distributed rewards mismatch");
    }

    function testRewardHandler() public {
        deal(spell, alice, 10_000 ether);

        pushPrank(alice);
        spell.safeApprove(address(staking), 10_000 ether);
        staking.deposit(10_000 ether);

        _distributeRewards(100 ether);

        uint before = mim.balanceOf(alice);
        staking.deposit(0);
        assertEq(mim.balanceOf(alice), before + 100 ether);
        before = mim.balanceOf(alice);
        staking.deposit(0);
        assertEq(mim.balanceOf(alice), before);

        pushPrank(staking.owner());
        staking.setRewardHandler(address(new RewardHandler()));
        popPrank();
    }

    function _distributeRewards(uint amount) internal {
        deal(mim, address(staking), amount, true);
        staking.updateReward();
    }
}
