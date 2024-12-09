// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import {SpellPowerStaking} from "/staking/SpellPowerStaking.sol";
import {RewardHandlerParams, IRewardHandler, TokenAmount} from "/staking/MultiRewards.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";

contract MockRewardHandler is IRewardHandler {
    function notifyRewards(address _user, address _to, TokenAmount[] memory _rewards, bytes memory _data) external payable {}
}

contract SpellPowerStakingTest is BaseTest {
    using SafeTransferLib for address;

    SpellPowerStaking staking;
    address stakingToken;
    address rewardToken;
    MockRewardHandler rewardHandler;

    function setUp() public override {
        super.setUp();

        rewardHandler = new MockRewardHandler();
        stakingToken = address(new ERC20Mock("Staking Token", "STK"));
        ERC20Mock(stakingToken).mint(tx.origin, 10_000_000 ether);
        rewardToken = address(new ERC20Mock("Reward Token", "RWD"));
        ERC20Mock(rewardToken).mint(tx.origin, 10_000_000 ether);
        staking = new SpellPowerStaking(stakingToken, tx.origin);
    }

    function testStakeBalanceOf() public {
        vm.startPrank(bob);
        deal(stakingToken, bob, 100 ether);
        stakingToken.safeApprove(address(staking), 100 ether);
        staking.stake(100 ether);
        assertEq(staking.balanceOf(bob), 100 ether);
    }

    function testCannotStakeZero() public {
        vm.expectRevert(abi.encodeWithSignature("ErrZeroAmount()"));
        staking.stake(0);
    }

    function testCannotWithdrawZero() public {
        vm.expectRevert(abi.encodeWithSignature("ErrZeroAmount()"));
        staking.withdraw(0);
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
        _setupReward(rewardToken, 60);
        _distributeReward(rewardToken, 10 ether);

        vm.startPrank(bob);
        deal(stakingToken, bob, 100 ether);
        uint256 amount = stakingToken.balanceOf(bob);
        assertEq(stakingToken.balanceOf(bob), amount);
        stakingToken.safeApprove(address(staking), amount);
        staking.stake(amount);
        assertEq(stakingToken.balanceOf(bob), 0);
        assertEq(staking.balanceOf(bob), amount);
        assertEq(staking.earned(bob, rewardToken), 0);

        advanceTime(100 seconds);

        uint256 earnings = staking.earned(bob, rewardToken);
        assertGt(earnings, 0);

        staking.exit();
        assertEq(stakingToken.balanceOf(bob), amount);
        assertEq(staking.balanceOf(bob), 0);
        assertEq(staking.earned(bob, rewardToken), 0);
        assertEq(rewardToken.balanceOf(bob), earnings);
    }

    function testCannotWithdrawDuringLockup() public {
        vm.prank(staking.owner());
        staking.setLockupPeriod(1 days);

        vm.startPrank(bob);
        deal(stakingToken, bob, 100 ether);
        stakingToken.safeApprove(address(staking), 100 ether);
        staking.stake(100 ether);

        vm.expectRevert(abi.encodeWithSignature("ErrLockedUp()"));
        staking.withdraw(100 ether);
    }

    function testCannotExitDuringLockup() public {
        vm.prank(staking.owner());
        staking.setLockupPeriod(1 days);

        vm.startPrank(bob);
        deal(stakingToken, bob, 100 ether);
        stakingToken.safeApprove(address(staking), 100 ether);
        staking.stake(100 ether);

        vm.expectRevert(abi.encodeWithSignature("ErrLockedUp()"));
        staking.exit();

        vm.expectRevert(abi.encodeWithSignature("ErrLockedUp()"));
        staking.exit(bob, RewardHandlerParams("", 0));
    }

    function testLastAddedUpdatedOnStake() public {
        vm.startPrank(bob);
        deal(stakingToken, bob, 100 ether);
        stakingToken.safeApprove(address(staking), 100 ether);

        uint256 stakingTimestamp = block.timestamp;
        staking.stake(100 ether);
        assertEq(staking.lastAdded(bob), stakingTimestamp);
    }

    function testGetRewardsWithParams() public {
        _setupReward(rewardToken, 60);
        _distributeReward(rewardToken, 10 ether);

        pushPrank(staking.owner());
        staking.setRewardHandler(address(rewardHandler));
        popPrank();

        vm.startPrank(bob);
        deal(stakingToken, bob, 100 ether);
        uint256 amount = stakingToken.balanceOf(bob);
        stakingToken.safeApprove(address(staking), amount);
        staking.stake(amount);
        assertEq(staking.earned(bob, rewardToken), 0);

        advanceTime(100 seconds);

        uint256 earnings = staking.earned(bob, rewardToken);
        assertGt(earnings, 0);

        bytes memory data = abi.encode("test data");
        RewardHandlerParams memory params = RewardHandlerParams(data, 0);
        staking.getRewards(bob, params);
        assertEq(staking.earned(bob, rewardToken), 0);
        assertEq(rewardToken.balanceOf(address(rewardHandler)), earnings);
        assertEq(staking.balanceOf(bob), amount);
    }

    function testExitWithParams() public {
        _setupReward(rewardToken, 60);
        _distributeReward(rewardToken, 10 ether);

        pushPrank(staking.owner());
        staking.setRewardHandler(address(rewardHandler));
        popPrank();

        vm.startPrank(bob);
        deal(stakingToken, bob, 100 ether);
        uint256 amount = stakingToken.balanceOf(bob);
        assertEq(stakingToken.balanceOf(bob), amount);
        stakingToken.safeApprove(address(staking), amount);
        staking.stake(amount);
        assertEq(stakingToken.balanceOf(bob), 0);
        assertEq(staking.balanceOf(bob), amount);
        assertEq(staking.earned(bob, rewardToken), 0);

        advanceTime(100 seconds);

        uint256 earnings = staking.earned(bob, rewardToken);
        assertGt(earnings, 0);

        bytes memory data = abi.encode("test data");
        RewardHandlerParams memory params = RewardHandlerParams(data, 0);
        staking.exit(bob, params);
        assertEq(stakingToken.balanceOf(bob), amount);
        assertEq(staking.balanceOf(bob), 0);
        assertEq(staking.earned(bob, rewardToken), 0);
        assertEq(rewardToken.balanceOf(address(rewardHandler)), earnings);
    }

    function _setupReward(address _rewardToken, uint256 duration) private {
        vm.startPrank(staking.owner());
        staking.grantRoles(alice, staking.ROLE_OPERATOR());
        staking.addReward(address(_rewardToken), duration);
        vm.stopPrank();
    }

    function _distributeReward(address _rewardToken, uint256 amount) private {
        vm.startPrank(alice);
        deal(_rewardToken, alice, amount);
        _rewardToken.safeApprove(address(staking), amount);
        staking.notifyRewardAmount(_rewardToken, amount);
    }
}
