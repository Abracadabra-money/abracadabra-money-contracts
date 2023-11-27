// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/MultiRewardsStaking.s.sol";
import {Address} from "openzeppelin-contracts/utils/Address.sol";
import {MultiRewardsStaking} from "periphery/MultiRewardsStaking.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

contract MultiRewardsStakingTest is BaseTest {
    using SafeTransferLib for address;

    MultiRewardsStaking staking;
    address stakingToken;
    address token;
    address token2;

    function setUp() public override {
        fork(ChainId.Arbitrum, 153716876);
        super.setUp();

        MultiRewardsStakingScript script = new MultiRewardsStakingScript();
        script.setTesting(true);

        (staking) = script.deploy();

        stakingToken = staking.stakingToken();
        token = toolkit.getAddress(block.chainid, "arb");
        token2 = toolkit.getAddress(block.chainid, "spell");
    }

    function testOnlyOwnerCanCall() public {
        vm.expectRevert("UNAUTHORIZED");
        staking.addReward(address(0), 0);

        vm.expectRevert("UNAUTHORIZED");
        staking.setRewardsDuration(address(0), 0);

        vm.expectRevert("UNAUTHORIZED");
        staking.recover(address(0), 0);

        vm.expectRevert("UNAUTHORIZED");
        staking.pause();

        vm.expectRevert("UNAUTHORIZED");
        staking.unpause();
    }

    function testOnlyOperatorsCanCall() public {
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSignature("NotAllowedOperator()"));
        staking.notifyRewardAmount(address(0), 0);
    }

    function testDurationNotPriorSet() public {
        vm.startPrank(staking.owner());
        assertEq(staking.rewardData(address(token)).rewardsDuration, 0);
        staking.addReward(address(token), 60);
        assertEq(staking.rewardData(address(token)).rewardsDuration, 60);
    }

    function testRewardPerTokenZeroSupply() public {
        vm.startPrank(staking.owner());
        staking.addReward(address(token), 60);
        assertEq(staking.rewardPerToken(address(token)), 0);
    }

    function testNotPaused() public {
        assertEq(staking.paused(), false);
    }

    function testPausable() public {
        vm.startPrank(staking.owner());
        staking.pause();
        assertEq(staking.paused(), true);

        vm.startPrank(staking.owner());
        staking.unpause();
        assertEq(staking.paused(), false);
    }

    function testExitWithdraws() public {
        vm.startPrank(bob);

        deal(stakingToken, bob, 100 ether);
        uint256 amount = stakingToken.balanceOf(bob);
        assertEq(stakingToken.balanceOf(bob), amount);

        stakingToken.safeApprove(address(staking), amount);
        staking.stake(amount);
        assertEq(stakingToken.balanceOf(bob), 0);

        assertEq(staking.balanceOf(bob), amount);
        staking.exit();

        assertEq(stakingToken.balanceOf(bob), amount);
        assertEq(staking.balanceOf(bob), 0);
    }

    function testExitWithdrawsReward() public {
        _setupReward(token, 60);
        _distributeReward(token, 10 ether);

        vm.startPrank(bob);
        deal(stakingToken, bob, 100 ether);
        uint256 amount = stakingToken.balanceOf(bob);
        assertEq(stakingToken.balanceOf(bob), amount);
        stakingToken.safeApprove(address(staking), amount);
        staking.stake(amount);
        assertEq(stakingToken.balanceOf(bob), 0);
        assertEq(staking.balanceOf(bob), amount);
        assertEq(staking.earned(bob, token), 0);

        advanceTime(100 seconds);

        uint256 earnings = staking.earned(bob, token);
        assertGt(earnings, 0);

        staking.exit();
        assertEq(stakingToken.balanceOf(bob), amount);
        assertEq(staking.balanceOf(bob), 0);
        assertEq(staking.earned(bob, token), 0);
        assertEq(token.balanceOf(bob), earnings);
    }

    function testUnstakedRevertsOnExit() public {
        assertEq(staking.balanceOf(bob), 0);
        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSignature("ErrZeroAmount()"));
        staking.exit();
    }

    function testNoLastTimeReward() public {
        vm.startPrank(staking.owner());
        staking.setOperator(alice, true);
        staking.addReward(address(token), 60);
        vm.stopPrank();
        assertEq(staking.lastTimeRewardApplicable(address(token)), 0);
    }

    function testRewardDurationUpdates() public {
        _setupReward(token, 60);
        _distributeReward(token, 10 ether);

        assertGt(staking.getRewardForDuration(address(token)), 0);
    }

    function testRewardPeriodFinish() public {
        _setupReward(token, 60);
        _distributeReward(token, 10 ether);

        vm.startPrank(staking.owner());
        vm.expectRevert(abi.encodeWithSignature("ErrRewardPeriodStillActive()"));
        staking.setRewardsDuration(token, 10 days);
    }

    function testUpdateRewardDuration() public {
        _setupReward(token, 60);
        advanceTime(100);

        vm.startPrank(staking.owner());
        staking.setRewardsDuration(token, 1000);
        assertEq(staking.rewardData(token).rewardsDuration, 1000);
    }

    function testUpdateRewardDurationNonInterferance() public {
        _setupReward(token, 60);
        _setupReward(token2, 2630000);

        uint256 rewardLength = staking.rewardData(token).rewardsDuration;
        uint256 slowLength = staking.rewardData(token2).rewardsDuration;

        assertGt(rewardLength, 0);
        assertGt(slowLength, 0);

        advanceTime(100);

        vm.startPrank(staking.owner());
        staking.setRewardsDuration(token, 10000);

        assertEq(staking.rewardData(token).rewardsDuration, 10000);
        assertEq(staking.rewardData(token2).rewardsDuration, slowLength);
    }

    function testNotifyRewardBeforePeriodFinish() public {
        uint256 rewardAmount = 10 ** 15;

        _setupReward(token, 60);
        _distributeReward(token, rewardAmount);

        uint256 initialRate = rewardAmount / 60;
        assertEq(staking.rewardData(token).rewardRate, initialRate);

        _distributeReward(token, rewardAmount);
        assertGt(staking.rewardData(token).rewardRate, initialRate);

        advanceTime(1000);
        _distributeReward(token, rewardAmount);
        assertEq(staking.rewardData(token).rewardRate, initialRate);

        vm.expectRevert(abi.encodeWithSignature("ErrRewardPeriodStillActive()"));
        _distributeReward(token, rewardAmount);
    }

    function _setupReward(address rewardToken, uint256 duration) private {
        vm.startPrank(staking.owner());
        staking.setOperator(alice, true);
        staking.addReward(address(rewardToken), duration);
        vm.stopPrank();
    }

    function _distributeReward(address rewardToken, uint256 amount) private {
        vm.startPrank(alice);
        deal(rewardToken, alice, amount);
        rewardToken.safeApprove(address(staking), amount);
        staking.notifyRewardAmount(rewardToken, amount);
    }
}
