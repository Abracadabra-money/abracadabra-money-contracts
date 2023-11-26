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

    function setUp() public override {
        fork(ChainId.Arbitrum, 153716876);
        super.setUp();

        MultiRewardsStakingScript script = new MultiRewardsStakingScript();
        script.setTesting(true);

        (staking) = script.deploy();

        stakingToken = staking.stakingToken();
        token = toolkit.getAddress(block.chainid, "arb");
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
        _setupSingleReward();

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
        console.log(earnings);
        assertGt(earnings, 0);

        staking.exit();
        assertEq(stakingToken.balanceOf(bob), amount);
        assertEq(staking.balanceOf(bob), 0);
        assertEq(staking.earned(bob, token), 0);
        assertEq(token.balanceOf(bob), earnings);
    }

    function _setupSingleReward() private {
        vm.startPrank(staking.owner());
        staking.setOperator(alice, true);
        staking.addReward(address(token), 60);
        vm.stopPrank();

        vm.startPrank(alice);
        deal(token, alice, 10 ether);
        token.safeApprove(address(staking), 10 ether);
        staking.notifyRewardAmount(token, 10 ether);
    }
}
