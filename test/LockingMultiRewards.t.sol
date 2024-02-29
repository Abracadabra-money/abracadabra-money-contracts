// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/LockingMultiRewards.s.sol";
import {Address} from "openzeppelin-contracts/utils/Address.sol";
import {LockingMultiRewards} from "staking/LockingMultiRewards.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {LibPRNG} from "solady/utils/LibPRNG.sol";
import {MockERC20} from "BoringSolidity/mocks/MockERC20.sol";
import {TimestampStore} from "./invariant/lockStaking/stores/TimestampStore.sol";
import {StakingHandler} from "./invariant/lockStaking/handlers/StakingHandler.sol";
import {ArrayUtils} from "./utils/ArrayUtils.sol";
import {LockingMultiRewardsScript} from "script/LockingMultiRewards.s.sol";
import {EpochBasedRewardDistributor} from "periphery/EpochBasedRewardDistributor.sol";

contract LockingMultiRewardsBase is BaseTest {
    using SafeTransferLib for address;

    LockingMultiRewards internal staking;
    address internal stakingToken;
    address internal token;
    address internal token2;
    uint256 internal constant NO_MINIMUM = 0;

    function _setupReward(address rewardToken) internal {
        pushPrank(staking.owner());
        staking.setOperator(alice, true);
        staking.addReward(address(rewardToken));
        popPrank();
    }

    function _distributeReward(address rewardToken, uint256 amount) internal {
        _distributeReward(rewardToken, amount, NO_MINIMUM);
    }

    function _distributeReward(address rewardToken, uint256 amount, uint minRemaining) internal {
        pushPrank(alice);
        deal(rewardToken, alice, amount);
        rewardToken.safeApprove(address(staking), amount);

        if (staking.remainingEpochTime() < minRemaining) {
            vm.expectRevert(abi.encodeWithSignature("ErrInsufficientRemainingTime()"));
        }
        staking.notifyRewardAmount(rewardToken, amount, minRemaining);
        popPrank();
    }
}

contract LockingMultiRewardsAdvancedTest is LockingMultiRewardsBase {
    using SafeTransferLib for address;
    using LibPRNG for LibPRNG.PRNG;
    uint256 constant BIPS = 10_000;

    event LogUnlocked(address indexed user, uint256 amount, uint256 index);
    event LogLockIndexChanged(address indexed user, uint256 fromIndex, uint256 toIndex);

    ArrayUtils internal arrayUtils;

    function setUp() public virtual override {
        fork(ChainId.Arbitrum, 153716876);
        super.setUp();

        LockingMultiRewardsScript script = new LockingMultiRewardsScript();
        script.setTesting(true);

        (staking) = script.deployWithParameters(toolkit.getAddress(block.chainid, "mim"), 30_000, 1 weeks, 13 weeks, tx.origin);

        stakingToken = staking.stakingToken();
        token = toolkit.getAddress(block.chainid, "usdc");
        arrayUtils = new ArrayUtils();

        _setupReward(token);

        vm.warp(0); // align to epoch start
    }

    function testDurationRatio() public {
        vm.expectRevert(abi.encodeWithSignature("ErrInvalidDurationRatio()"));
        new LockingMultiRewards(address(0), 10_001, 2 weeks, 5 weeks, tx.origin);
        new LockingMultiRewards(address(0), 10_001, 5 weeks, 10 weeks, tx.origin);
    }

    function _getAPY() private view returns (uint256) {
        uint256 rewardsPerYear = staking.rewardsForDuration(token) * 52;
        uint256 totalSupply = staking.totalSupply(); // value is $1

        // apy in bips
        return (rewardsPerYear * BIPS) / totalSupply;
    }

    function testAddExistingReward() public {
        pushPrank(staking.owner());
        staking.addReward(address(0x123));

        vm.expectRevert(abi.encodeWithSignature("ErrRewardAlreadyExists()"));
        staking.addReward(address(0x123));

        staking.addReward(address(0x456));
        popPrank();
    }

    function testNotifyValidReward() public {
        pushPrank(staking.owner());
        address nonRewardToken = address(new MockERC20(100 ether));
        nonRewardToken.safeApprove(address(staking), 100 ether);
        vm.expectRevert(abi.encodeWithSignature("ErrInvalidTokenAddress()"));
        staking.notifyRewardAmount(nonRewardToken, 100 ether, NO_MINIMUM);

        staking.addReward(nonRewardToken);
        staking.notifyRewardAmount(nonRewardToken, 100 ether, NO_MINIMUM);
        popPrank();
    }

    function testMaxRewards() public {
        uint256 numRewardsToAdd = 5 - staking.rewardTokensLength();

        pushPrank(staking.owner());
        for (uint256 i = 0; i < numRewardsToAdd; i++) {
            staking.addReward(address(uint160(i + 1)));
        }

        vm.expectRevert(abi.encodeWithSignature("ErrMaxRewardsExceeded()"));
        staking.addReward(address(uint160(6)));

        popPrank();
    }

    function testRescueStakingTokenSameAsRewardToken() public {
        _setupReward(stakingToken);

        pushPrank(bob);
        deal(stakingToken, bob, 100 ether);
        stakingToken.safeApprove(address(staking), 100 ether);
        staking.stake(100 ether, false);
        _distributeReward(stakingToken, 120 ether);

        staking.withdraw(1 ether);
        popPrank();

        assertEq(stakingToken.balanceOf(address(staking)), 219 ether);
        assertEq(staking.stakingTokenBalance(), 99 ether);

        pushPrank(staking.owner());
        vm.expectRevert();
        staking.recover(stakingToken, 199 ether);
        popPrank();

        assertEq(stakingToken.balanceOf(address(staking.owner())), 0);

        pushPrank(staking.owner());
        staking.recover(stakingToken, 100 ether);
        assertEq(stakingToken.balanceOf(address(staking.owner())), 100 ether);
        staking.recover(stakingToken, 20 ether);
        assertEq(stakingToken.balanceOf(address(staking.owner())), 120 ether);
        vm.expectRevert();
        staking.recover(stakingToken, 1);
        popPrank();
    }

    function testStakeSimpleWithLocking() public {
        uint256 amount = 10 ** 10;

        pushPrank(bob);
        deal(stakingToken, bob, 10 ** 15);
        uint256 initialBalance = stakingToken.balanceOf(bob);
        stakingToken.safeApprove(address(staking), amount);
        staking.stake(amount, true);

        // boosted amounts
        assertEq(staking.totalSupply(), amount * 3);
        assertEq(staking.balanceOf(bob), amount * 3);
        assertEq(stakingToken.balanceOf(bob), initialBalance - amount);
    }

    function testNotifyRewards() public {
        // start of the epoch, reward rate should be whole rewardDuration
        assertEq(staking.remainingEpochTime(), 7 days);
        _distributeReward(token, 100 ether);

        LockingMultiRewards.Reward memory rewardData = staking.rewardData(token);
        assertEq(rewardData.rewardRate, 100 ether / uint(7 days));

        // now advance 3 days into the epoch, the reward rate should be scale on the remaining time
        // of the epoch: 4 days
        advanceTime(3 days);
        assertEq(staking.remainingEpochTime(), 4 days);

        _distributeReward(token, 100 ether);

        // remaining reward of previous epoch + new reward
        // (100 ether / 7) * 4
        uint rolledOverAmount = rewardData.rewardRate * 4 days;
        assertApproxEqRel(rolledOverAmount, 57.15 ether, 0.001 ether);

        uint newRewardRate = 100 ether + rolledOverAmount;
        rewardData = staking.rewardData(token);
        assertEq(rewardData.rewardRate, newRewardRate / uint(4 days));

        // advance at epoch end - 3 days
        // simulate notify reward with a min of 4 days,
        // should fail as we are too late within the epoch
        advanceTime(1 days);
        _distributeReward(token, 100 ether, 4 days); // reverts
        assertEq(staking.rewardData(token).rewardRate, rewardData.rewardRate); // unchanged
        _distributeReward(token, 100 ether, 3 days);
    }

    function testLockedRewards() public {
        // align to an epoch start for simplicity
        vm.warp(1707368400); // Thu Feb 08 2024 00:00:00 UTC

        assertEq(staking.nextEpoch(), 1707955200); // Thu Feb 15 2024 00:00:00 UTC
        token2 = toolkit.getAddress(block.chainid, "arb");

        _setupReward(token2);
        _distributeReward(token, 500 ether);
        _distributeReward(token2, 100 ether);

        pushPrank(bob);
        deal(stakingToken, bob, 100 ether);
        uint256 amount = stakingToken.balanceOf(bob);
        assertEq(stakingToken.balanceOf(bob), amount, "wrong balance");

        stakingToken.safeApprove(address(staking), amount);
        staking.stake(amount, false);
        assertEq(stakingToken.balanceOf(bob), 0);

        uint nextEpoch = staking.nextEpoch();

        advanceTime(3 days);

        uint earning1 = staking.earned(bob, token);
        uint earning2 = staking.earned(bob, token2);
        uint earning3;

        assertApproxEqRel(earning1, 250 ether, 0.5 ether);
        assertApproxEqRel(earning2, 50 ether, 0.5 ether);

        // verify that getRewards won't transfer rewards immediately but create a new lock

        staking.getRewards();
        assertEq(token.balanceOf(bob), 0, "should not transfer rewards");
        assertEq(token2.balanceOf(bob), 0, "should not transfer rewards");

        LockingMultiRewards.RewardLock memory rewardLock = staking.userRewardLock(bob);
        assertEq(rewardLock.items.length, 2, "should create 2 lock entry for each reward");
        assertEq(rewardLock.items[0].amount, earning1);
        assertEq(rewardLock.items[1].amount, earning2);
        assertEq(rewardLock.unlockTime, nextEpoch, "should unlock at the next epoch");

        assertEq(staking.earned(bob, token), 0, "should reset earned rewards");
        assertEq(staking.earned(bob, token2), 0, "should reset earned rewards");

        // claiming rewards again should not change anything
        staking.getRewards();
        assertEq(token.balanceOf(bob), 0, "should not transfer rewards");
        assertEq(token2.balanceOf(bob), 0, "should not transfer rewards");
        rewardLock = staking.userRewardLock(bob);
        assertEq(rewardLock.items.length, 2, "should create 2 lock entry for each reward");
        assertEq(rewardLock.items[0].amount, earning1);
        assertEq(rewardLock.items[1].amount, earning2);
        assertEq(rewardLock.unlockTime, nextEpoch, "should unlock at the next epoch");

        {
            // Add rewards to the current lock
            advanceTime(1 days);

            assertApproxEqRel(staking.earned(bob, token), 71 ether, 0.5 ether);
            assertApproxEqRel(staking.earned(bob, token2), 14 ether, 0.5 ether);

            earning1 += staking.earned(bob, token);
            earning2 += staking.earned(bob, token2);

            // verify that getRewards won't transfer rewards immediately but create a new lock
            staking.getRewards();
            assertEq(token.balanceOf(bob), 0, "should not transfer rewards");
            assertEq(token2.balanceOf(bob), 0, "should not transfer rewards");

            rewardLock = staking.userRewardLock(bob);
            assertEq(rewardLock.items.length, 2, "should create 2 lock entry for each reward");
            assertEq(rewardLock.items[0].amount, earning1);
            assertEq(rewardLock.items[1].amount, earning2);
            assertEq(rewardLock.unlockTime, nextEpoch, "should unlock at the next epoch");
        }

        // add a new reward in between
        address token3 = toolkit.getAddress(block.chainid, "usdt");
        _setupReward(token3);
        _distributeReward(token3, 100 ether); // 100 ether distributed over the remaining epoch time

        uint previousEarning3;

        {
            // Add rewards to the current lock
            advanceTime(1 days);
            previousEarning3 = (100 ether / staking.remainingEpochTime()) * 1 days;
            // should stay on the same epoch
            assertEq(staking.nextEpoch(), 1707955200, "should stay on the same epoch");
            assertEq(block.timestamp, 1707368400 + 5 days);

            assertApproxEqRel(staking.earned(bob, token), 71 ether, 0.5 ether);
            assertApproxEqRel(staking.earned(bob, token2), 14 ether, 0.5 ether);
            assertApproxEqRel(staking.earned(bob, token3), previousEarning3, 0.5 ether);

            earning1 += staking.earned(bob, token);
            earning2 += staking.earned(bob, token2);
            earning3 += staking.earned(bob, token3);

            // verify that getRewards won't transfer rewards immediately but create a new lock
            staking.getRewards();

            assertEq(token.balanceOf(bob), 0, "should not transfer rewards");
            assertEq(token2.balanceOf(bob), 0, "should not transfer rewards");
            assertEq(token3.balanceOf(bob), 0, "should not transfer rewards");

            rewardLock = staking.userRewardLock(bob);
            assertEq(rewardLock.unlockTime, nextEpoch, "should unlock at the next epoch");
            assertEq(rewardLock.items.length, 3, "should an extra locked entry");
            assertEq(rewardLock.items[0].amount, earning1, "wrong amount 1");
            assertEq(rewardLock.items[1].amount, earning2, "wrong amount 2");
            assertEq(rewardLock.items[2].amount, earning3, "wrong amount 3");
        }

        // now advance to next epoch + 1 day
        // we expect getReward to claim the previous earning and lock the newest amount
        {
            advanceTime(2 days);
            nextEpoch = 1708560000;
            assertEq(staking.nextEpoch(), nextEpoch); // Thu Feb 22 2024 00:00:00

            // distribute over the remaining epoch time
            _distributeReward(token, 100 ether);
            _distributeReward(token2, 100 ether);
            _distributeReward(token3, 100 ether);

            advanceTime(1 days);

            uint256 newRewards = ((100 ether / staking.remainingEpochTime()) * 1 days);

            // account for the previous rewards from advancing 2 days
            assertApproxEqRel(staking.earned(bob, token), 142 ether + newRewards, 0.1 ether, "wrong earned amount 1");
            assertApproxEqRel(staking.earned(bob, token2), 28 ether + newRewards, 0.1 ether, "wrong earned amount 2");
            assertApproxEqRel(staking.earned(bob, token3), previousEarning3 + newRewards, 0.1 ether, "wrong earned amount 3");

            uint nextEarning1 = staking.earned(bob, token);
            uint nextEarning2 = staking.earned(bob, token2);
            uint nextEarning3 = staking.earned(bob, token3);

            staking.getRewards();
            assertEq(token.balanceOf(bob), earning1, "should transfer rewards");
            assertEq(token2.balanceOf(bob), earning2, "should transfer rewards");
            assertEq(token3.balanceOf(bob), earning3, "should transfer rewards");

            rewardLock = staking.userRewardLock(bob);
            assertEq(rewardLock.unlockTime, nextEpoch, "should unlock at the next epoch");
            assertEq(rewardLock.items.length, 3);
            assertEq(rewardLock.items[0].amount, nextEarning1, "wrong amount 1");
            assertEq(rewardLock.items[1].amount, nextEarning2, "wrong amount 2");
            assertEq(rewardLock.items[2].amount, nextEarning3, "wrong amount 3");
        }
    }

    function testProcessExpiredLocks() public {
        {
            // create 1 locking staking position that expired
            pushPrank(bob);
            deal(stakingToken, bob, 100 ether);
            stakingToken.safeApprove(address(staking), 100 ether);
            staking.stake(100 ether, true);
            popPrank();

            advanceTime(14 weeks);
            pushPrank(staking.owner());
            address[] memory users = new address[](1);
            users[0] = bob;

            uint256[] memory indexes = new uint256[](1);
            indexes[0] = _getExpiredLockIndex(bob, true);

            vm.expectEmit(true, true, true, true);
            emit LogUnlocked(bob, 100 ether, 0);

            staking.processExpiredLocks(users, indexes);
            assertEq(staking.userLocks(bob).length, 0);
            popPrank();
        }

        uint256 snapshot;

        {
            pushPrank(bob);
            deal(stakingToken, bob, 100 ether);
            stakingToken.safeApprove(address(staking), 100 ether);
            staking.stake(100 ether, true);
            popPrank();

            pushPrank(alice);
            deal(stakingToken, alice, 100 ether);
            stakingToken.safeApprove(address(staking), 100 ether);
            staking.stake(100 ether, true);
            popPrank();

            advanceTime(1 weeks);

            pushPrank(bob);
            deal(stakingToken, bob, 100 ether);
            stakingToken.safeApprove(address(staking), 100 ether);
            staking.stake(100 ether, true);
            popPrank();

            pushPrank(alice);
            deal(stakingToken, alice, 100 ether);
            stakingToken.safeApprove(address(staking), 100 ether);
            staking.stake(100 ether, true);
            popPrank();

            snapshot = vm.snapshot();
            advanceTime(14 weeks);

            pushPrank(staking.owner());
            address[] memory users = new address[](2);
            users[0] = bob;
            users[1] = alice;

            uint256[] memory indexes = new uint256[](2);

            {
                indexes[0] = _getExpiredLockIndex(bob, true);
                indexes[1] = _getExpiredLockIndex(alice, true);

                vm.expectEmit(true, true, true, true);
                emit LogUnlocked(bob, 100 ether, 0);
                emit LogUnlocked(alice, 100 ether, 0);

                staking.processExpiredLocks(users, indexes);
                assertEq(staking.userLocks(bob).length, 1);
                assertEq(staking.userLocks(alice).length, 1);
            }

            // in case of delayed lock release, call again
            {
                indexes[0] = _getExpiredLockIndex(bob, true);
                indexes[1] = _getExpiredLockIndex(alice, true);

                vm.expectEmit(true, true, true, true);
                emit LogUnlocked(bob, 100 ether, 0);
                emit LogUnlocked(alice, 100 ether, 0);

                staking.processExpiredLocks(users, indexes);
                assertEq(staking.userLocks(bob).length, 0);
                assertEq(staking.userLocks(alice).length, 0);
            }
            popPrank();
        }

        {
            vm.revertTo(snapshot);
            advanceTime(13 weeks);

            pushPrank(staking.owner());
            address[] memory users = new address[](2);
            users[0] = bob;
            users[1] = alice;

            uint256[] memory indexes = new uint256[](2);

            {
                indexes[0] = _getExpiredLockIndex(bob, true);
                indexes[1] = _getExpiredLockIndex(alice, true);

                vm.expectEmit(true, true, true, true);
                emit LogUnlocked(bob, 100 ether, 0);
                emit LogUnlocked(alice, 100 ether, 0);

                staking.processExpiredLocks(users, indexes);
                assertEq(staking.userLocks(bob).length, 1);
                assertEq(staking.userLocks(alice).length, 1);
            }

            // should not release the other lock and revert
            {
                indexes[0] = 0;
                indexes[1] = 0;

                vm.expectRevert(abi.encodeWithSignature("ErrLockNotExpired()"));
                staking.processExpiredLocks(users, indexes);
                assertEq(staking.userLocks(bob).length, 1);
                assertEq(staking.userLocks(alice).length, 1);
            }

            advanceTime(1 weeks);

            // now it should release the second lock
            {
                indexes[0] = _getExpiredLockIndex(bob, true);
                indexes[1] = _getExpiredLockIndex(alice, true);

                vm.expectEmit(true, true, true, true);
                emit LogUnlocked(bob, 100 ether, 0);
                emit LogUnlocked(alice, 100 ether, 0);

                staking.processExpiredLocks(users, indexes);
                assertEq(staking.userLocks(bob).length, 0);
                assertEq(staking.userLocks(alice).length, 0);
            }
            popPrank();
        }
    }

    function testMinLockingAmount() public {
        uint256 amount = 10 ** 10;

        pushPrank(staking.owner());
        staking.setMinLockAmount(0);
        popPrank();

        pushPrank(bob);
        deal(stakingToken, bob, 10 ** 15);
        uint256 initialBalance = stakingToken.balanceOf(bob);
        stakingToken.safeApprove(address(staking), amount);
        staking.stake(amount, true);

        // boosted amounts
        assertEq(staking.totalSupply(), amount * 3);
        assertEq(staking.balanceOf(bob), amount * 3);
        assertEq(stakingToken.balanceOf(bob), initialBalance - amount);

        deal(stakingToken, bob, 10 ether);
        stakingToken.safeApprove(address(staking), 10 ether);
        staking.stake(amount, true);

        advanceTime(1 weeks);
        deal(stakingToken, bob, 10 ether);
        stakingToken.safeApprove(address(staking), 10 ether);
        staking.stake(amount, true);

        // now activate the min lock
        // will be effective only on _new_ locks
        // same week doesn't create a new lock

        pushPrank(staking.owner());
        staking.setMinLockAmount(10 ether);
        popPrank();

        deal(stakingToken, bob, 10 ether);
        stakingToken.safeApprove(address(staking), 10 ether);
        staking.stake(10 ether, true);

        advanceTime(1 weeks);
        deal(stakingToken, bob, 10 ether);
        stakingToken.safeApprove(address(staking), 10 ether);
        vm.expectRevert(abi.encodeWithSignature("ErrLockAmountTooSmall()"));
        staking.stake(amount, true);
    }

    function testStakeSimpleWithAndWithoutLocking() public {
        vm.warp(1700859429); // original fork block

        {
            uint amount = 10_000 ether;

            vm.startPrank(bob);
            deal(stakingToken, bob, amount);
            stakingToken.safeApprove(address(staking), amount);
            staking.stake(amount / 2, true);
            staking.stake(amount / 2, false);

            assertEq(staking.userLocks(bob).length, 1);
            LockingMultiRewards.Balances memory bal = staking.balances(bob);
            assertEq(bal.locked, amount / 2);
            assertEq(bal.unlocked, amount / 2);

            // boosted amounts
            assertEq(staking.totalSupply(), (amount / 2) + ((amount / 2) * 3));
            assertEq(staking.balanceOf(bob), (amount / 2) + ((amount / 2) * 3));
        }
        {
            uint amount = 10_000 ether;

            vm.startPrank(bob);
            deal(stakingToken, bob, amount);
            stakingToken.safeApprove(address(staking), amount);
            staking.stake(amount, true);

            // It should lock on the same one
            assertEq(staking.userLocks(bob).length, 1);
        }

        // current block timestamp is:
        // Fri Nov 24 2023 20:57:09 UTC
        // align to Sat Nov 25 2023 00:00:18
        advanceTime(10971 seconds);
        assertEq(block.timestamp, 1700870400);

        advanceTime(5 days - 1 seconds);
        {
            uint amount = 10_000 ether;

            vm.startPrank(bob);
            deal(stakingToken, bob, amount);
            stakingToken.safeApprove(address(staking), amount);
            staking.stake(amount, true);

            // It should lock on the same one
            assertEq(staking.userLocks(bob).length, 1);
        }

        // 1 second later we are exactly on the next epoch
        advanceTime(1 seconds);
        {
            uint amount = 10_000 ether;

            vm.startPrank(bob);
            deal(stakingToken, bob, amount);
            stakingToken.safeApprove(address(staking), amount);
            staking.stake(amount, true);

            // It should lock on the same one
            assertEq(staking.userLocks(bob).length, 2);
        }
    }

    function testReleaseLocks() public {
        // BOB
        // 10_000 unlocked
        // 10_000 locked
        // total: 40_000
        {
            uint amount = 20_000 ether;
            vm.startPrank(bob);
            deal(stakingToken, bob, amount);
            stakingToken.safeApprove(address(staking), amount);
            staking.stake(amount / 2, true);
            staking.stake(amount / 2, false);
        }

        // ALICE
        // 5_000 unlocked
        // 5_000 locked
        // total: 20_000
        {
            uint amount = 10_000 ether;
            vm.startPrank(alice);
            deal(stakingToken, alice, amount);
            stakingToken.safeApprove(address(staking), amount);
            staking.stake(amount / 2, true);
            staking.stake(amount / 2, false);
        }

        advanceTime(1 weeks);

        // BOB
        // 10_000 unlocked
        // 10_000 locked
        // total: 40_000 + 40_000 = 80_000
        {
            uint amount = 20_000 ether;
            vm.startPrank(bob);
            deal(stakingToken, bob, amount);
            stakingToken.safeApprove(address(staking), amount);
            staking.stake(amount / 2, true);
            staking.stake(amount / 2, false);
        }

        assertEq(staking.userLocks(bob).length, 2);
        assertEq(staking.userLocks(alice).length, 1);
        assertEq(staking.balanceOf(bob), 80_000 ether);
        assertEq(staking.balanceOf(alice), 20_000 ether);

        LockingMultiRewards.LockedBalance[] memory locks = staking.userLocks(bob);
        vm.warp(locks[0].unlockTime);

        address[] memory users = new address[](2);
        users[0] = bob;
        users[1] = alice;

        uint256[] memory indexes = new uint256[](2);

        pushPrank(staking.owner());
        indexes[0] = _getExpiredLockIndex(bob, true);
        indexes[1] = _getExpiredLockIndex(alice, true);
        staking.processExpiredLocks(users, indexes);
        popPrank();

        assertEq(staking.userLocks(bob).length, 1);
        assertEq(staking.userLocks(alice).length, 0);

        // Now that alice and bob locked tokens are released, the total supply should be:
        // bob: 20_000 unlocked + 10_000 + 10_000 locked boosted
        // alice: 10_000 unlocked
        // total: 40_000 + 30_000 = 70_000
        assertEq(staking.totalSupply(), 70_000 ether);
    }

    function testMultipleUsersApy() public {
        _distributeReward(token, 1_000 ether);

        // BOB
        // 10_000 unlocked
        // 10_000 locked
        {
            uint amount = 20_000 ether;
            vm.startPrank(bob);
            deal(stakingToken, bob, amount);
            stakingToken.safeApprove(address(staking), amount);
            staking.stake(amount / 2, true);
            staking.stake(amount / 2, false);
            assertEq(staking.balanceOf(bob), 40_000 ether);
        }

        // yearly reward is 1_000 ethers * 52 weeks = 52_000 ethers
        // apy = 52_000 / (10_000 unlocked + 10_000 locked boosted) ≈ 130% APY
        assertApproxEqAbs(_getAPY(), 13000, 100);

        // ALICE
        // 10_000 unlocked
        // 10_000 locked
        {
            uint amount = 10_000 ether;
            vm.startPrank(alice);
            deal(stakingToken, alice, amount);
            stakingToken.safeApprove(address(staking), amount);
            staking.stake(amount / 2, true);
            staking.stake(amount / 2, false);
        }

        // Alice dillutes the APY
        // yearly reward is 1_000 ethers * 52 weeks = 52_000 ethers
        // bob balance is 40_000 ethers
        // alice balance is 20_000 ethers (5k unlocked + 5k locked boosted)
        // apy = 52_000 / (40_000 + 20_000) ≈ 86.66% APY
        assertApproxEqAbs(_getAPY(), 8600, 100);

        // BOB unstake 10_000 unlocked
        {
            assertEq(staking.unlocked(bob), 10_000 ether);
            vm.startPrank(bob);
            staking.withdraw(10_000 ether);
            assertEq(staking.balanceOf(bob), 30_000 ether);
        }

        // bob balance is 30_000 ethers (10k locked boosted)
        // alice balance is 20_000 ethers (5k unlocked + 5k locked boosted)
        // apy = 52_000 / (30_000 + 20_000) ≈ 104% APY
        assertApproxEqAbs(_getAPY(), 10400, 100);

        // wait for the lock to expire
        LockingMultiRewards.LockedBalance[] memory locks = staking.userLocks(bob);
        vm.warp(locks[0].unlockTime);

        // release bob lock
        // intentionnaly skip alice lock release to test the apy
        address[] memory users = new address[](1);
        users[0] = bob;

        uint256[] memory indexes = new uint256[](1);

        pushPrank(staking.owner());
        indexes[0] = _getExpiredLockIndex(bob, true);
        staking.processExpiredLocks(users, indexes);
        popPrank();

        // bob balance is 10k unlocked
        // alice balance is 20_000 ethers (5k unlocked + 5k locked boosted)
        // apy = 52_000 / (10_000 + 20_000) ≈ 173.33% APY
        assertApproxEqAbs(_getAPY(), 17333, 100);
    }

    function testMaxLocks() public {
        pushPrank(bob);

        // fillup all locks
        for (uint i = 0; i < 13; i++) {
            uint amount = 10_000 ether;

            deal(stakingToken, bob, amount);
            stakingToken.safeApprove(address(staking), amount);
            staking.stake(amount, true);
            advanceTime(1 weeks);
            assertEq(staking.userLocks(bob).length, i + 1);
        }

        assertEq(staking.userLocks(bob).length, 13);

        {
            uint amount = 10_000 ether;
            deal(stakingToken, bob, amount);
            stakingToken.safeApprove(address(staking), amount);
            vm.expectRevert(abi.encodeWithSignature("ErrMaxUserLocksExceeded()"));
            staking.stake(amount, true);
        }

        address[] memory users = new address[](1);
        users[0] = bob;
        // align to latest lock
        LockingMultiRewards.LockedBalance[] memory locks = staking.userLocks(bob);
        vm.warp(locks[0].unlockTime);

        // release bob locks one by one each week
        for (uint i = 0; i < 13; i++) {
            pushPrank(staking.owner());

            uint256[] memory indexes = new uint256[](1);
            indexes[0] = _getExpiredLockIndex(bob, true);
            staking.processExpiredLocks(users, indexes);
            popPrank();
            assertEq(staking.userLocks(bob).length, 12 - i);
            advanceTime(1 weeks);
        }
    }

    function testFuzzStaking(
        address[10] memory fuzzedUsers,
        uint256[13][10] memory depositPerWeek,
        uint256[13][10] memory numDepositPerWeek,
        uint256 maxUsers
    ) public onlyProfile("ci") {
        address[] memory users = new address[](fuzzedUsers.length);
        for (uint256 i = 0; i < fuzzedUsers.length; i++) {
            users[i] = fuzzedUsers[i];
        }

        users = arrayUtils.uniquify(users);

        maxUsers = bound(maxUsers, 1, users.length);
        LibPRNG.PRNG memory prng;
        prng.seed(8723489723489723); // some seed

        vm.warp(0); // reset time for simplicity

        // Each week
        for (uint256 i = 0; i < 13; i++) {
            // 100_000 rewards per week
            _distributeReward(token, 100_000 ether);

            // Each users
            for (uint256 j = 0; j < maxUsers; j++) {
                if (users[j] == address(0)) {
                    continue;
                }
                if (numDepositPerWeek[j][i] == 0 || depositPerWeek[j][i] == 0) {
                    continue;
                }

                // random-ish 0 to 10 deposits per week per users
                uint256 numDeposits = numDepositPerWeek[j][i] % 10;
                if (numDeposits == 0) {
                    continue;
                }

                uint256 amount = bound(depositPerWeek[j][i], 1, 100_000_000_000 ether);
                uint256 amountPerDeposit = amount / numDeposits;

                if (amountPerDeposit == 0) {
                    continue;
                }

                deal(stakingToken, users[j], amount);

                pushPrank(users[j]);
                stakingToken.safeApprove(address(staking), amount);
                popPrank();

                for (uint256 k = 0; k < numDeposits; k++) {
                    // every new stake locked or not we're expecting:
                    // 1. _rewardData[token].rewardPerTokenStored to increase
                    // 2. _rewardData[token].lastUpdateTime to be updated to the current block.timestamp
                    // 3. rewards[user][token] and serRewardPerTokenPaid[user][token] for this user to be updated
                    //
                    advanceTime(5 minutes); // 5 minutes between each deposit
                    _testFuzzStakingStake(users[j], amountPerDeposit, prng.next() % 2 == 0 ? true : false);
                }
            }

            _testFuzzStakingCheckLockingConsistency(users, maxUsers);

            advanceTime(1 weeks);
        }

        _testFuzzStakingGetRewardsAndExit(users, maxUsers);
    }

    function _testFuzzStakingCheckLockingConsistency(address[] memory users, uint256 numUsers) private {
        for (uint256 i = 0; i < numUsers; i++) {
            LockingMultiRewards.LockedBalance[] memory locks = staking.userLocks(users[i]);
            LockingMultiRewards.Balances memory balances = staking.balances(users[i]);

            uint256 totalLocked = 0;
            uint256 totalUnlocked = balances.unlocked;

            for (uint256 j = 0; j < locks.length; j++) {
                if (locks[j].unlockTime > block.timestamp) {
                    // check that there's no duplicated locks
                    for (uint256 k = 0; k < locks.length; k++) {
                        if (k == j) {
                            continue;
                        }
                        if (locks[j].unlockTime == locks[k].unlockTime) {
                            assertEq(locks[j].amount, locks[k].amount, "duplicate locks");
                        }
                    }

                    totalLocked += locks[j].amount;
                }
            }

            assertEq(staking.locked(users[i]), totalLocked, "locked amount should be equal to the sum of all locks");
            assertEq(staking.unlocked(users[i]), totalUnlocked, "unlocked amount should be equal to the sum of all unlocked");
            assertEq(
                staking.balanceOf(users[i]),
                (totalLocked * 3) + totalUnlocked,
                "balanceOf should be equal to the sum of all unlocked and boosted locked"
            );

            assertEq(balances.locked, totalLocked, "balances.locked should equal totalLocked");
            assertEq(balances.unlocked, totalUnlocked, "balances.unlocked should equal totalUnlocked");
        }
    }

    function _testFuzzStakingGetRewardsAndExit(address[] memory users_, uint256 maxUsers) private {
        //  release all locks and expect everyone to be able to withdraw all their rewards and exit the staking
        advanceTime(100 weeks);
        _releaseAllLocks(users_);

        for (uint256 j = 0; j < maxUsers; j++) {
            address _user = users_[j];
            if (_user == address(0)) {
                continue;
            }
            assertEq(staking.userLocks(_user).length, 0);
            assertEq(staking.unlocked(_user), staking.balanceOf(_user));
            assertEq(staking.locked(_user), 0);

            pushPrank(_user);
            uint256 earned = staking.earned(_user, token);
            uint256 balanceBefore = token.balanceOf(_user);
            staking.getRewards();
            assertEq(token.balanceOf(_user) - balanceBefore, 0);
            LockingMultiRewards.RewardLock memory rewardLock = staking.userRewardLock(_user);
            assertEq(rewardLock.items.length, 1, "should create 1 lock entry for each reward");
            assertEq(rewardLock.items[0].amount, earned);

            uint256 balanceOf = staking.balanceOf(_user);
            if (balanceOf > 0) {
                staking.withdraw(staking.balanceOf(_user));
            }

            assertEq(staking.balanceOf(_user), 0);
            assertEq(staking.unlocked(_user), 0);
            assertEq(staking.locked(_user), 0);
            popPrank();
        }

        assertEq(staking.totalSupply(), 0);
    }

    function _getNumUsersWithExpiredLocks(address[] memory users_) private view returns (uint256) {
        uint256 numUsersWithExpiredLocks;

        for (uint i = 0; i < users_.length; i++) {
            if (users_[i] == address(0)) {
                continue;
            }

            LockingMultiRewards.LockedBalance[] memory locks = staking.userLocks(users_[i]);
            for (uint j = 0; j < locks.length; j++) {
                if (locks[j].unlockTime <= block.timestamp) {
                    numUsersWithExpiredLocks++;
                    break;
                }
            }
        }

        return numUsersWithExpiredLocks;
    }

    function _releaseAllLocks(address[] memory users_) private {
        for (;;) {
            uint256 numUsersWithExpiredLocks = _getNumUsersWithExpiredLocks(users_);

            if (numUsersWithExpiredLocks == 0) {
                break;
            }

            // convert users to dynamic
            address[] memory users = new address[](numUsersWithExpiredLocks);
            uint256[] memory indexes = new uint256[](numUsersWithExpiredLocks);

            uint256 idx;
            for (uint i = 0; i < users_.length; i++) {
                if (users_[i] == address(0)) {
                    continue;
                }

                LockingMultiRewards.LockedBalance[] memory locks = staking.userLocks(users_[i]);

                for (uint j = 0; j < locks.length; j++) {
                    if (locks[j].unlockTime <= block.timestamp) {
                        users[idx] = users_[i];
                        indexes[idx] = _getExpiredLockIndex(users_[i], true);
                        idx++;
                        break;
                    }
                }
            }

            pushPrank(staking.owner());
            staking.processExpiredLocks(users, indexes);

            for (uint i = 0; i < users.length; i++) {
                _checkLastLockIndex(users[i]);
            }

            popPrank();
        }

        // verify that all locks are released
        for (uint i = 0; i < users_.length; i++) {
            if (users_[i] == address(0)) {
                continue;
            }
            assertEq(staking.userLocks(users_[i]).length, 0, "all locks should be released");
        }
    }

    function _testFuzzStakingStake(address user, uint256 amount, bool locking) private {
        LockingMultiRewards.Reward memory reward = staking.rewardData(token);
        uint256 previousRewardPerToken = reward.rewardPerTokenStored;
        uint256 previousLastUpdateTime = reward.lastUpdateTime;
        uint256 previousReward = staking.rewards(user, token);
        uint256 previousRewardPerTokenPaid = staking.userRewardPerTokenPaid(user, token);
        uint256 previousTotalSupply = staking.totalSupply();
        uint256 previousBalanceOf = staking.balanceOf(user);

        // since we advance 5 seconds between each deposit, we expect reward.lastUpdateTime to be stalled until stake is called
        assertLt(previousLastUpdateTime, block.timestamp, "previousLastUpdateTime should be less than block.timestamp");

        pushPrank(user);
        staking.stake(amount, locking);
        _checkLastLockIndex(user);
        popPrank();

        reward = staking.rewardData(token);

        // This won't be updated for the first ever stake
        if (previousTotalSupply > 0) {
            assertGt(
                reward.rewardPerTokenStored,
                previousRewardPerToken,
                "reward.rewardPerTokenStored should be greater than previousRewardPerToken"
            );
        }
        assertGt(staking.totalSupply(), previousTotalSupply, "staking.totalSupply should be greater than previousTotalSupply");
        assertEq(reward.lastUpdateTime, block.timestamp, "reward.lastUpdateTime not updated");

        /// no rewards for the first user stake
        /// ignore anything below 1 ether, not enough to
        /// harvest anything in 5 minutes and leads to 0 rewards.
        if (previousBalanceOf > 1 ether) {
            assertGt(staking.rewards(user, token), previousReward, "rewards[user][token] should be greater than previousReward");
            assertGt(
                staking.userRewardPerTokenPaid(user, token),
                previousRewardPerTokenPaid,
                "userRewardPerTokenPaid[user][token] should be greater than previousRewardPerTokenPaid"
            );
        }
    }

    function _checkLastLockIndex(address user) public {
        if (user == address(0)) {
            return;
        }

        LockingMultiRewards.LockedBalance[] memory locks = staking.userLocks(user);

        uint256 highestUnlockTime;
        uint256 lastLockIndex;

        for (uint256 j = 0; j < locks.length; j++) {
            if (locks[j].unlockTime > highestUnlockTime) {
                highestUnlockTime = locks[j].unlockTime;
                lastLockIndex = j;
            }
        }

        assertEq(staking.lastLockIndex(user), lastLockIndex, "lastLockIndex should be equal to the last lock index");
    }

    /// Scenario:
    /// Bob stake 1000 tokens
    /// Alice stake 4000 tokens
    /// Bob stake 1000 tokens locked
    ///
    /// Alice: 4000 total
    /// Bob: 4000 total
    /// Deposit 100 rewards for 1 week
    /// Apy is 100 * 52 / 8000 = 65%
    /// Rewards per day is 100 / 7 = 14.28
    /// Wait 3 days
    /// Alice and Bob rewards should be 14.28 * 3 / 2 = 21.42
    function testRewardConsistenciesScenario1() public {
        uint256 bobAmount1 = 1000 ether;
        uint256 bobAmount2 = 1000 ether;
        uint256 aliceAmount = 4000 ether;

        pushPrank(bob);
        deal(stakingToken, bob, bobAmount1 + bobAmount2);
        stakingToken.safeApprove(address(staking), bobAmount1 + bobAmount2);
        staking.stake(bobAmount1, false);
        assertEq(staking.balanceOf(bob), bobAmount1, "bob balance should be equal to bobAmount1");
        staking.stake(bobAmount2, true);
        assertEq(staking.balanceOf(bob), bobAmount1 + (bobAmount2 * 3), "bob balance should be equal to bobAmount1 + (bobAmount2 * 3)");
        popPrank();

        pushPrank(alice);
        deal(stakingToken, alice, aliceAmount);
        stakingToken.safeApprove(address(staking), aliceAmount);
        staking.stake(aliceAmount, false);
        assertEq(staking.balanceOf(alice), aliceAmount, "alice balance should be equal to aliceAmount");
        popPrank();

        _distributeReward(token, 100 ether);
        advanceTime(3 days);

        assertApproxEqAbs(staking.earned(alice, token), 21.42 ether, 0.05 ether, "alice should have earned 21.42 tokens");
        assertApproxEqAbs(staking.earned(bob, token), 21.42 ether, 0.05 ether, "bob should have earned 21.42 tokens");
    }

    /// Scenario:
    /// Deposit 100 rewards for 1 week
    /// Alice stake 1000 tokens
    /// Alice stake 1000 tokens locked
    /// Bob stake 1000 tokens unlocked
    /// Wait 4 days
    /// Alice withdraw 500 tokens
    /// Wait 4 days
    /// Alice stake 500 tokens locked
    /// Bob stake 500 tokens locked
    /// Locks count for alice is 2
    /// Locks count for bob is 1
    /// Warp to alice lock expiration
    /// Release locks
    /// Deposit 100 rewards for 1 week
    /// Wait 1 week
    /// Process expired locks
    /// Try relocking bob unlocked amoung again
    /// Bob should be getting more yields than alice
    function testRewardConsistenciesScenario2() public {
        _distributeReward(token, 100 ether);
        {
            pushPrank(alice);
            deal(stakingToken, alice, 1000 ether);
            stakingToken.safeApprove(address(staking), 1000 ether);
            staking.stake(1000 ether, false);
            assertEq(staking.balanceOf(alice), 1000 ether, "alice balance should be equal to 1000 ether");
        }
        {
            pushPrank(alice);
            deal(stakingToken, alice, 1000 ether);
            stakingToken.safeApprove(address(staking), 1000 ether);
            staking.stake(1000 ether, true);
            assertEq(staking.balanceOf(alice), 4000 ether, "alice balance should be equal to 4000 ether");
        }
        {
            pushPrank(bob);
            deal(stakingToken, bob, 1000 ether);
            stakingToken.safeApprove(address(staking), 1000 ether);
            staking.stake(1000 ether, false);
            assertEq(staking.balanceOf(bob), 1000 ether, "bob balance should be equal to 1000 ether");
        }

        advanceTime(4 days);

        // 0.0114 * 5000 = 57.14
        assertApproxEqAbs(staking.rewardPerToken(token), 0.0114 ether, 0.0001 ether, "wrong rewardPerToken");
        LockingMultiRewards.Reward memory reward = staking.rewardData(token);
        assertEq(reward.lastUpdateTime, block.timestamp - 4 days, "lastUpdateTime should be 4 days ago");

        {
            // 100 / 7 * 4 = 57.14
            // alice rewards should be 57.14 * (4000 / 5000) = 45.71)
            // bob rewards should be 57.14 * (1000 / 5000) = 11.42)
            assertApproxEqAbs(staking.earned(alice, token), 45.71 ether, 0.05 ether, "alice should have earned 45.71 tokens");
            assertApproxEqAbs(staking.earned(bob, token), 11.42 ether, 0.05 ether, "bob should have earned 11.42 tokens");

            pushPrank(alice);
            staking.withdraw(500 ether); // update reward lastUpdateTime
            assertEq(staking.balanceOf(alice), 3500 ether, "alice balance should be equal to 3500 ether");

            assertApproxEqAbs(staking.rewards(alice, token), 45.71 ether, 0.05 ether, "stamped rewards for alice should be 45.71 tokens");
            assertEq(staking.earned(alice, token), staking.rewards(alice, token), "earned should be equal to stamped rewards");
            assertEq(staking.rewards(bob, token), 0, "stamped rewards for bob should be 0 tokens"); // bob didn't do any actions so rewards mapping should remains 0
        }

        uint snapshotBefore = vm.snapshot();

        // Scenario where we advance 4 days without claiming rewards
        {
            advanceTime(4 days); // so that alice next lock goes to the week after. max reward duration should last 3 days here.

            reward = staking.rewardData(token);
            assertEq(reward.lastUpdateTime, block.timestamp - 4 days, "lastUpdateTime should be 4 days ago");
            assertEq(staking.totalSupply(), 4500 ether);

            // 0.02 * 4500 = 90
            assertApproxEqAbs(staking.rewardPerToken(token), 0.02 ether, 0.001 ether, "wrong rewardPerToken");

            // 100 / 7 * 3 = 42.84  (less than previous because of the 3 days duration left over the 7 days rewards period)
            // alice rewards: 42.84 * (3500 / 4500) = 33.32 + existing = 79
            // bob rewards: 42.84 * (1000 / 4500) = 9.52 + existing = 21
            assertApproxEqAbs(staking.earned(alice, token), 79 ether, 0.1 ether, "alice should have earned around 79 tokens");
            assertApproxEqAbs(staking.earned(bob, token), 21 ether, 0.1 ether, "bob should have earned around 21 tokens");

            pushPrank(alice);
            deal(stakingToken, alice, 500 ether);
            stakingToken.safeApprove(address(staking), 500 ether);
            staking.stake(500 ether, true);
            popPrank();

            assertEq(staking.balanceOf(alice), 5000 ether, "alice balance should be equal to 5000 ether");
        }

        uint snapshotAfter = vm.snapshot();

        // Test from snapshotBefore, but this time harvest the rewards and
        // check if the reported earned reward are only the delta
        {
            vm.revertTo(snapshotBefore);
            pushPrank(alice);
            staking.getRewards();
            LockingMultiRewards.RewardLock memory rewardLock = staking.userRewardLock(alice);
            assertApproxEqAbs(rewardLock.items[0].amount, 45.71 ether, 0.01 ether, "alice should have around 45.71 tokens");
            assertEq(token.balanceOf(alice), 0);

            popPrank();

            pushPrank(bob);
            staking.getRewards();
            rewardLock = staking.userRewardLock(bob);
            assertApproxEqAbs(rewardLock.items[0].amount, 11.42 ether, 0.01 ether, "bob should have around 11.42 tokens");

            assertEq(token.balanceOf(bob), 0);
            popPrank();

            assertEq(staking.earned(alice, token), 0, "alice should have earned 0 tokens");
            assertEq(staking.earned(bob, token), 0, "bob should have earned 0 tokens");

            advanceTime(4 days);

            // Now earned should only report the delta since the amounts was harvested
            assertApproxEqAbs(staking.earned(alice, token), 33.33 ether, 0.01 ether, "alice should have earned around 33.33 tokens");
            assertApproxEqAbs(staking.earned(bob, token), 9.52 ether, 0.01 ether, "bob should have earned around 9.52 tokens");
        }

        // Continue the normal path from there.
        vm.revertTo(snapshotAfter);
        {
            pushPrank(bob);
            deal(stakingToken, bob, 500 ether);
            stakingToken.safeApprove(address(staking), 500 ether);
            staking.stake(500 ether, true);
            assertEq(staking.balanceOf(bob), 2500 ether, "bob balance should be equal to 2500 ether");
        }

        assertEq(staking.userLocks(alice).length, 2, "alice should have 2 locks");
        assertEq(staking.userLocks(bob).length, 1, "bob should have 1 lock");
        assertEq(staking.totalSupply(), 7500 ether, "total supply should be 7500 ether");

        // release alice locks
        address[] memory users = new address[](1);
        users[0] = alice;
        uint256[] memory indexes = new uint256[](1);

        {
            LockingMultiRewards.LockedBalance[] memory locks = staking.userLocks(alice);
            vm.warp(locks[0].unlockTime);

            pushPrank(staking.owner());
            indexes[0] = _getExpiredLockIndex(alice, true);
            staking.processExpiredLocks(users, indexes);
            popPrank();

            assertEq(staking.userLocks(alice).length, 1, "alice should have 1 locks");
            assertEq(staking.userLocks(bob).length, 1, "bob should have 1 lock");
            assertEq(staking.totalSupply(), 5500 ether, "total supply should be 5500 ether");
        }

        // advance 2 days, but there was not reward deposit, earned should stay the same
        advanceTime(2 days);
        assertApproxEqAbs(staking.earned(alice, token), 79 ether, 0.1 ether, "alice should have earned around 79 tokens");
        assertApproxEqAbs(staking.earned(bob, token), 21 ether, 0.1 ether, "bob should have earned around 21 tokens");

        // Deposit 100 rewards for 1 week
        _distributeReward(token, 100 ether);

        uint remainingEpochTime = staking.remainingEpochTime();
        assertEq(remainingEpochTime, 432000);

        // Harvest all rewards for simplicity
        pushPrank(alice);
        staking.getRewards();
        popPrank();

        pushPrank(bob);
        staking.getRewards();
        popPrank();

        // earned amounts should now be all 0
        assertEq(staking.earned(alice, token), 0, "alice should have earned 0 tokens");
        assertEq(staking.earned(bob, token), 0, "bob should have earned 0 tokens");
        assertEq(staking.totalSupply(), 5500 ether, "total supply should be 5500 ether");
        assertEq(staking.balanceOf(alice), 3000 ether, "alice balance should be equal to 3000 ether");
        assertEq(staking.balanceOf(bob), 2500 ether, "bob balance should be equal to 2500 ether");

        {
            // Wrap to earliest alice lock expiration
            LockingMultiRewards.LockedBalance[] memory locks = staking.userLocks(alice);
            assertEq(locks[0].unlockTime - block.timestamp, 5 days, "should be 5 days left before alice lock expires");
            vm.warp(locks[0].unlockTime);

            users = new address[](2);
            users[0] = alice;
            users[1] = bob;
            indexes = new uint256[](2);

            pushPrank(staking.owner());
            indexes[0] = _getExpiredLockIndex(alice, true);
            indexes[1] = _getExpiredLockIndex(bob, true);
            staking.processExpiredLocks(users, indexes);
            popPrank();

            // Both alice and bob lock release but earned should have been accumulated with
            // their respective boosted during 5 days.
            uint baseRewards = (100 ether / remainingEpochTime) * 5 days;
            assertApproxEqRel(baseRewards, 100 ether, 0.00001 ether);

            // alice rewards: 100 * (3000 / 5500) = 54.54
            // bob rewards: 100 * (2500 / 5500) = 45.45
            assertApproxEqRel(staking.earned(alice, token), 54.54 ether, 0.1 ether, "alice should have earned around 38 tokens");
            assertApproxEqRel(staking.earned(bob, token), 45.45 ether, 0.1 ether, "bob should have earned around 32 tokens");

            assertEq(staking.userLocks(alice).length, 0, "alice should have 0 locks");
            assertEq(staking.userLocks(bob).length, 0, "bob should have 0 lock");

            // relock bob unlocked amount
            pushPrank(bob);
            staking.lock(staking.unlocked(bob));
            popPrank();

            assertEq(staking.userLocks(bob).length, 1, "bob should have 1 lock");

            // Harvest all rewards for simplicity
            pushPrank(alice);
            staking.getRewards();
            popPrank();

            pushPrank(bob);
            staking.getRewards();
            popPrank();

            advanceTime(1 weeks);

            // no more rewards at this point
            assertEq(staking.earned(alice, token), 0);
            assertEq(staking.earned(bob, token), 0);
        }
    }

    function testLockUnlocked() public {
        uint amount = 10_000 ether;

        pushPrank(bob);
        deal(stakingToken, bob, amount);
        stakingToken.safeApprove(address(staking), amount);
        staking.stake(amount, false);
        assertEq(staking.balanceOf(bob), amount);

        vm.expectRevert(); // underflow
        staking.lock(amount + 1);

        assertEq(staking.lockedSupply(), 0);
        assertEq(staking.unlockedSupply(), amount);
        assertEq(staking.locked(bob), 0, "locked amount should be 0");
        assertEq(staking.unlocked(bob), amount, "unlocked amount should be equal to the amount staked");
        assertEq(staking.userLocks(bob).length, 0, "userLocks should be empty");
        staking.lock(amount);
        assertEq(staking.userLocks(bob).length, 1, "userLocks should have 1 lock");
        assertEq(staking.locked(bob), amount, "locked amount should be equal to the amount locked");
        assertEq(staking.unlocked(bob), 0, "unlocked amount should be 0");
        assertEq(staking.lockedSupply(), amount);
        assertEq(staking.unlockedSupply(), 0);
        popPrank();
    }

    function _getExpiredLockIndex(address user, bool revertWhenNoLocks) private view returns (uint256 index) {
        uint oldestUnlockTime = type(uint).max;

        uint lastUserLockIndex = staking.lastLockIndex(user);
        uint length = staking.userLocksLength(user);

        if (length == 1) {
            return lastUserLockIndex;
        }

        // find the oldest lock
        for (uint256 i; i < length; i++) {
            if (lastUserLockIndex == i) {
                continue;
            }

            uint unlockTime = staking.userLocks(user)[i].unlockTime;

            if (unlockTime <= block.timestamp && unlockTime <= oldestUnlockTime) {
                index = i;
                oldestUnlockTime = unlockTime;
            }
        }

        if (oldestUnlockTime != type(uint).max) {
            return index;
        }

        if (revertWhenNoLocks) {
            revert("no expired lock");
        }
    }
}

contract LockingMultiRewardsSimpleTest is LockingMultiRewardsBase {
    using SafeTransferLib for address;

    function setUp() public override {
        fork(ChainId.Arbitrum, 153716876);
        super.setUp();

        LockingMultiRewardsScript script = new LockingMultiRewardsScript();
        script.setTesting(true);

        (staking) = script.deployWithParameters(toolkit.getAddress(block.chainid, "mim"), 30_000, 1 days, 1 weeks, tx.origin);

        stakingToken = staking.stakingToken();
        token = toolkit.getAddress(block.chainid, "arb");
        token2 = toolkit.getAddress(block.chainid, "spell");

        vm.warp(0); // align to epoch start
    }

    function testOnlyOwnerCanCall() public {
        vm.expectRevert("UNAUTHORIZED");
        staking.addReward(address(0));

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
        staking.notifyRewardAmount(address(0), 0, NO_MINIMUM);
    }

    function testRewardPerTokenZeroSupply() public {
        vm.startPrank(staking.owner());
        staking.addReward(address(token));
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

    function testCannotStakeZero() public {
        vm.expectRevert(abi.encodeWithSignature("ErrZeroAmount()"));
        staking.stake(0, false);
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
        staking.stake(amount, false);
        assertEq(stakingToken.balanceOf(bob), 0);

        assertEq(staking.balanceOf(bob), amount);
        staking.withdrawWithRewards(staking.unlocked(bob));

        assertEq(stakingToken.balanceOf(bob), amount);
        assertEq(staking.balanceOf(bob), 0);
    }

    function testExitWithdrawsReward() public {
        _setupReward(token);
        _distributeReward(token, 10 ether);

        vm.startPrank(bob);
        deal(stakingToken, bob, 100 ether);
        uint256 amount = stakingToken.balanceOf(bob);
        assertEq(stakingToken.balanceOf(bob), amount);
        stakingToken.safeApprove(address(staking), amount);
        staking.stake(amount, false);
        assertEq(stakingToken.balanceOf(bob), 0);
        assertEq(staking.balanceOf(bob), amount);
        assertEq(staking.earned(bob, token), 0);

        advanceTime(100 seconds);

        uint256 earnings = staking.earned(bob, token);
        assertGt(earnings, 0);

        staking.withdrawWithRewards(staking.unlocked(bob));
        assertEq(stakingToken.balanceOf(bob), amount);
        assertEq(staking.balanceOf(bob), 0);
        assertEq(staking.earned(bob, token), 0);
        assertEq(token.balanceOf(bob), 0);

        // check reward lock
        LockingMultiRewards.RewardLock memory rewardLock = staking.userRewardLock(bob);
        assertEq(rewardLock.items.length, 1);
        assertEq(rewardLock.items[0].amount, earnings);
    }

    function testUnstakedRevertsOnWithdrawWithRewards() public {
        assertEq(staking.balanceOf(bob), 0);
        assertEq(staking.unlocked(bob), 0);
        vm.startPrank(bob);
        uint256 unlocked = staking.unlocked(bob);
        vm.expectRevert(abi.encodeWithSignature("ErrZeroAmount()"));
        staking.withdrawWithRewards(unlocked);
    }

    function testNoLastTimeReward() public {
        vm.startPrank(staking.owner());
        staking.setOperator(alice, true);
        staking.addReward(address(token));
        vm.stopPrank();
        assertEq(staking.lastTimeRewardApplicable(address(token)), 0);
    }

    function testRewardDurationUpdates() public {
        _setupReward(token);
        _distributeReward(token, 10 ether);

        assertGt(staking.rewardsForDuration(address(token)), 0);
    }

    function testRewardCreationTransfersBalance() public {
        uint256 amount = 10 ** 10;
        _setupReward(token);
        _distributeReward(token, amount);
        assertEq(staking.rewardData(token).rewardRate, amount / 1 days);
        assertEq(staking.rewardsForDuration(token), (amount / 1 days) * 1 days);
    }

    function testLastTimeRewardApplicable() public {
        uint256 rewardAmount = 10 ** 15;
        _setupReward(token);
        uint256 lastTime = staking.lastTimeRewardApplicable(token);
        uint256 currentTime;

        for (uint256 i = 0; i < 5; i++) {
            _distributeReward(token, rewardAmount);
            advanceTime(60);
            currentTime = staking.lastTimeRewardApplicable(token);
            assertGt(currentTime, lastTime);
            lastTime = currentTime;
        }
    }

    function testNotifyRewardBeforePeriodFinish() public {
        _setupReward(token);
        uint256 rewardAmount = 10 ** 15;

        _distributeReward(token, rewardAmount);

        uint256 initialRate = rewardAmount / 1 days;
        assertEq(staking.rewardData(token).rewardRate, initialRate);

        _distributeReward(token, rewardAmount);
        assertGt(staking.rewardData(token).rewardRate, initialRate);

        advanceTime(1 days);
        _distributeReward(token, rewardAmount);
        assertEq(staking.rewardData(token).rewardRate, initialRate);

        vm.expectRevert(abi.encodeWithSignature("ErrRewardPeriodStillActive()"));
        _distributeReward(token, rewardAmount);
    }

    function testRewardPerTokenUpdates() public {
        uint256 amount = 10 ** 10;

        _setupReward(token);
        _distributeReward(token, amount);

        vm.startPrank(bob);
        deal(stakingToken, bob, amount);
        stakingToken.safeApprove(address(staking), amount);
        staking.stake(amount, false);

        advanceTime(100);
        assertGt(staking.rewardPerToken(address(token)), 0);
    }

    function testStakeBalanceOf() public {
        vm.startPrank(bob);
        deal(stakingToken, bob, 100 ether);
        stakingToken.safeApprove(address(staking), 100 ether);
        staking.stake(100 ether, false);
        assertEq(staking.balanceOf(bob), 100 ether);
    }

    function testMultipleRewards() public {
        uint256 n = 5;
        address[] memory rewards = new address[](n);
        address[] memory accounts = new address[](n);
        accounts[0] = createUser("user1", address(0x1), 0);
        accounts[1] = createUser("user2", address(0x2), 0);
        accounts[2] = createUser("user3", address(0x3), 0);
        accounts[3] = createUser("user4", address(0x4), 0);
        accounts[4] = createUser("user5", address(0x5), 0);

        for (uint256 i = 0; i < n; i++) {
            rewards[i] = address(new MockERC20(10_000_000 ether));
            _setupReward(rewards[i]);
            _distributeReward(rewards[i], 10 ether);

            pushPrank(accounts[i]);
            deal(stakingToken, accounts[i], 10000);
            stakingToken.safeApprove(address(staking), 10000);
            staking.stake(10000, false);
            popPrank();
        }

        advanceTime(120);
        for (uint256 i = 0; i < n; i++) {
            assertGt(staking.earned(accounts[i], rewards[i]), 0);
        }
    }

    function testSupplyBalanceUpdates() public {
        uint256 amount = 10 ** 10;

        vm.startPrank(bob);
        deal(stakingToken, bob, 10 ** 15);
        uint256 initialBalance = stakingToken.balanceOf(bob);
        stakingToken.safeApprove(address(staking), amount);
        staking.stake(amount, false);

        assertEq(staking.totalSupply(), amount);
        assertEq(staking.balanceOf(bob), amount);
        assertEq(stakingToken.balanceOf(bob), initialBalance - amount);
    }

    function testDifferentRewardAmounts() public {
        uint256 amount = 10 ** 12;

        _setupReward(token);
        _distributeReward(token, 10 ** 15);
        _setupReward(token2);
        _distributeReward(token2, 10 ** 14);

        pushPrank(bob);
        deal(stakingToken, bob, amount);
        stakingToken.safeApprove(address(staking), amount);
        staking.stake(amount, false);

        advanceTime(1000);
        uint256 reward1Earning = staking.earned(bob, token);
        uint256 reward2Earning = staking.earned(bob, token2);

        uint256 initialStakingBalance = stakingToken.balanceOf(bob);
        uint256 initialReward1Balance = token.balanceOf(bob);
        uint256 initialReward2Balance = token2.balanceOf(bob);

        staking.withdrawWithRewards(staking.unlocked(bob));
        popPrank();

        uint256 finalStakingGain = stakingToken.balanceOf(bob) - initialStakingBalance;
        uint256 finalReward1Gain = token.balanceOf(bob) - initialReward1Balance;
        uint256 finalReward2Gain = token2.balanceOf(bob) - initialReward2Balance;

        // assert reward_2_earnings * 0.98 <= reward_1_earnings // 10 <= reward_2_earnings * 1.02
        // assert final_reward2_gain * 0.98 <= final_reward_gain // 10 <= final_reward2_gain * 1.02
        // assert final_base_gain == amount
        assertLe((reward2Earning * 98) / 100, reward1Earning);
        assertLe(reward1Earning / 10, (reward2Earning * 102) / 100);
        assertLe((finalReward2Gain * 98) / 100, finalReward1Gain);
        assertLe(finalReward1Gain / 10, (finalReward2Gain * 102) / 100);
        assertEq(finalStakingGain, amount);
    }

    function testCannotWithdrawMoreThanDeposit() public {
        vm.startPrank(bob);
        deal(stakingToken, bob, 100 ether);
        stakingToken.safeApprove(address(staking), 100 ether);
        staking.stake(100 ether, false);
        vm.expectRevert();
        staking.withdraw(101 ether);
    }

    function testCannotWithdrawMoreThanDepositIfBalanceExists() public {
        pushPrank(bob);
        deal(stakingToken, bob, 100 ether);
        stakingToken.safeApprove(address(staking), 100 ether);
        staking.stake(100 ether, false);
        popPrank();

        pushPrank(carol);
        deal(stakingToken, carol, 100 ether);
        stakingToken.safeApprove(address(staking), 100 ether);
        staking.stake(100 ether, false);
        popPrank();

        vm.expectRevert();
        pushPrank(carol);
        staking.withdraw(100 ether + 1);
        popPrank();
    }

    function testSupplyBalanceChangesOnWithdraw() public {
        uint256 amount = 10 ** 10;
        vm.startPrank(bob);
        deal(stakingToken, bob, amount);
        stakingToken.safeApprove(address(staking), amount);
        staking.stake(amount, false);

        uint256 initialSupply = staking.totalSupply();
        assertEq(staking.totalSupply(), amount);

        uint256 initialBalance = staking.balanceOf(bob);
        uint256 withdrawAmount = amount / 3;
        staking.withdraw(withdrawAmount);

        assertEq(staking.totalSupply(), initialSupply - withdrawAmount);
        assertEq(staking.balanceOf(bob), initialBalance - withdrawAmount);
        assertEq(stakingToken.balanceOf(bob), withdrawAmount);
    }

    function testCompoundingRewardsDuringRewardPeriod() public {
        _setupReward(staking.stakingToken());

        uint256 amount = 1 ether;

        // Bob stakes and locks
        pushPrank(bob);
        deal(stakingToken, bob, 1 ether);
        stakingToken.safeApprove(address(staking), type(uint256).max);
        staking.stake(amount, true);
        popPrank();

        // Alice stakes and locks
        pushPrank(alice);
        deal(stakingToken, alice, 1 ether);
        stakingToken.safeApprove(address(staking), type(uint256).max);
        staking.stake(amount, true);
        popPrank();

        // Distribute reward
        _distributeReward(staking.stakingToken(), 1_000 ether);

        // Time has elapsed, so reward tokens have accumulated
        advanceTime(1 days);

        pushPrank(bob);
        uint256 balBeforeGetRewards = MockERC20(staking.stakingToken()).balanceOf(bob);
        staking.getRewards();
        uint256 balAfterGetRewards = MockERC20(staking.stakingToken()).balanceOf(bob);
        assertEq(balAfterGetRewards, balBeforeGetRewards, "bal increased after getting rewards");
    }
}

/// @notice Common logic needed by all invariant tests.
/// @author Guardian Audits
/// Adopted from Sablier-Labs invariant setup: https://github.com/sablier-labs/v2-core
contract LockingMultiRewardsInvariantTest is LockingMultiRewardsAdvancedTest {
    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    TimestampStore internal timestampStore;
    StakingHandler internal stakingHandler;

    /*//////////////////////////////////////////////////////////////////////////
                                     MODIFIERS
    //////////////////////////////////////////////////////////////////////////*/

    modifier useCurrentTimestamp() {
        vm.warp(timestampStore.currentTimestamp());
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/
    function setUp() public override {
        super.setUp();

        // Deploy the handlers.
        timestampStore = new TimestampStore();
        stakingHandler = new StakingHandler(stakingToken, timestampStore, staking, address(0x01));

        // Label the contracts.
        vm.label({account: address(timestampStore), newLabel: "TimestampStore"});

        // Target only the handlers for invariant testing (to avoid getting reverts).
        targetContract(address(stakingHandler));

        // Prevent these contracts from being fuzzed as `msg.sender`.
        excludeSender(address(timestampStore));
        excludeSender(address(stakingHandler));
    }

    function invariantUserLocksDoNotExceedCap() public useCurrentTimestamp {
        address[] memory currActors = stakingHandler.allActors();
        for (uint256 i = 0; i < currActors.length; i++) {
            assertLe(staking.userLocksLength(currActors[i]), staking.maxLocks(), "Max locks exceeded");
        }
    }

    function invariantEarnedDoesNotExceedRewardTokenBalance() public useCurrentTimestamp {
        address[] memory currActors = stakingHandler.allActors();
        uint256 sumEarned;
        uint256 currEarned;
        for (uint256 i = 0; i < currActors.length; i++) {
            currEarned = staking.earned(currActors[i], token);
            sumEarned += currEarned;
        }
        assertLe(sumEarned, MockERC20(token).balanceOf(address(staking)), "Sum Earned > Balance Of Reward Token");
    }

    function invariantSumUserLockedEqualsTotalLocked() public {
        address[] memory currActors = stakingHandler.allActors();
        uint256 sumLocked;
        uint256 currLocked;
        for (uint256 i = 0; i < currActors.length; i++) {
            currLocked = staking.locked(currActors[i]);
            sumLocked += currLocked;
        }
        assertEq(sumLocked, staking.lockedSupply(), "Sum Locked != Total Locked");
    }

    function invariantSumUserUnlockedEqualsTotalUnlocked() public {
        address[] memory currActors = stakingHandler.allActors();
        uint256 sumUnlocked;
        uint256 currUnlocked;
        for (uint256 i = 0; i < currActors.length; i++) {
            currUnlocked = staking.unlocked(currActors[i]);
            sumUnlocked += currUnlocked;
        }
        assertEq(sumUnlocked, staking.unlockedSupply(), "Sum Unlocked != Total Unlocked");
    }

    function invariantSumBalancesEqualsTotalSupply() public {
        address[] memory currActors = stakingHandler.allActors();
        uint256 sumBalance;
        uint256 currBalance;
        for (uint256 i = 0; i < currActors.length; i++) {
            currBalance = staking.balanceOf(currActors[i]);
            sumBalance += currBalance;
        }
        assertEq(sumBalance, staking.totalSupply(), "Sum Balances != Total Supply");
    }

    function invariantLastRewardTimeApplicableNotLessThanLastUpdate() public {
        LockingMultiRewards.Reward memory reward = staking.rewardData(token);

        if (reward.exists) {
            assertGe(staking.lastTimeRewardApplicable(token), reward.lastUpdateTime, "Last reward time applicable < last update time");
        }
    }

    function invariantLatestLockHasLatestUnlockTime() public {
        address[] memory currActors = stakingHandler.allActors();
        uint256 lastLockIndex;

        LockingMultiRewards.LockedBalance[] memory userLocks;
        for (uint i = 0; i < currActors.length; i++) {
            lastLockIndex = staking.lastLockIndex(currActors[i]);
            userLocks = staking.userLocks(currActors[i]);

            uint256 latestUnlockTime;
            uint256 latestUnlockTimeIndex;
            for (uint j = 0; j < userLocks.length; j++) {
                if (userLocks[j].unlockTime > latestUnlockTime) {
                    latestUnlockTime = userLocks[j].unlockTime;
                    latestUnlockTimeIndex = j;
                }
            }
            console.logAddress(currActors[i]);
            assertEq(latestUnlockTimeIndex, lastLockIndex, "Last Lock Index != Most Recent Lock");
        }
    }
}

contract EpochBasedRewardDistributorTest is BaseTest {
    using SafeTransferLib for address;

    LockingMultiRewards staking;
    EpochBasedRewardDistributor distributor;

    function setUp() public override {
        fork(ChainId.Arbitrum, 178777813);
        super.setUp();

        LockingMultiRewardsScript script = new LockingMultiRewardsScript();
        script.setTesting(true);

        (staking, distributor) = script.deploy();

        vm.warp(staking.epoch()); // align to epoch start
    }

    function testDistribution() public {
        address arb = toolkit.getAddress(block.chainid, "arb");

        pushPrank(bob);
        deal(staking.stakingToken(), bob, 100 ether);
        staking.stakingToken().safeApprove(address(staking), 100 ether);
        staking.stake(100 ether, true);
        popPrank();

        pushPrank(distributor.owner());
        vm.expectRevert(abi.encodeWithSignature("ErrInvalidRewardToken()"));
        distributor.deposit(address(0x123), 123);

        deal(arb, distributor.owner(), 200 ether);
        arb.safeApprove(address(distributor), 200 ether);

        assertFalse(distributor.ready());

        distributor.deposit(arb, 100 ether);
        distributor.deposit(arb, 100 ether);

        pushPrank(alice);
        deal(arb, alice, 1 ether, true);
        arb.safeTransfer(address(distributor), 1 ether);
        popPrank();

        // transfered token to the distributor should be retrievable with withdraw but
        // never considered about usable rewards
        assertEq(arb.balanceOf(address(distributor)), 201 ether, "balance should be equal to 201 ether");
        assertEq(distributor.balanceOf(arb), 200 ether, "distributor balance should be equal to 200 ether");

        assertEq(staking.rewardData(arb).rewardRate, 0);

        vm.expectRevert(abi.encodeWithSignature("ErrNotReady()"));
        distributor.distribute();

        // warp to next epoch - 1
        vm.warp(staking.nextEpoch() - 1);
        vm.expectRevert(abi.encodeWithSignature("ErrNotReady()"));
        distributor.distribute();

        advanceTime(1 seconds);
        distributor.distribute();
        assertEq(staking.rewardData(arb).rewardRate, 200 ether / staking.rewardsDuration());
        assertEq(staking.rewardData(arb).rewardPerTokenStored, 0);

        assertEq(arb.balanceOf(address(distributor)), 1 ether);
        assertEq(distributor.balanceOf(arb), 0);

        // withdraw 1 ether
        distributor.withdraw(arb, distributor.owner(), 1 ether);
        assertEq(arb.balanceOf(address(distributor)), 0);
        assertEq(distributor.balanceOf(arb), 0);

        arb.safeApprove(address(distributor), 1 ether);
        distributor.deposit(arb, 1 ether);

        // cannot distribute again, even if we distribute
        vm.expectRevert(abi.encodeWithSignature("ErrNotReady()"));
        distributor.distribute();

        // advance to the epoch but too late in it, triggering the min remaining time
        vm.warp(staking.nextEpoch() + 1 hours + 1);
        vm.expectRevert(abi.encodeWithSignature("ErrInsufficientRemainingTime()"));
        distributor.distribute();

        vm.warp(staking.nextEpoch() + 1 hours);
        assertApproxEqRel(staking.earned(bob, arb), 200 ether, 0.0001 ether);
        distributor.distribute();

        // reward rate should be inflated compared to distribute it exactly at the epoch start
        assertEq(staking.rewardData(arb).rewardRate, 1 ether / (staking.rewardsDuration() - 1 hours));

        assertEq(arb.balanceOf(address(distributor)), 0);
        assertEq(distributor.balanceOf(arb), 0);

        popPrank();
    }
}
