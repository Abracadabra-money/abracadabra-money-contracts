// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/LockingMultiRewards.s.sol";
import {Address} from "openzeppelin-contracts/utils/Address.sol";
import {LockingMultiRewards} from "staking/LockingMultiRewards.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {LibPRNG} from "solady/utils/LibPRNG.sol";
import {MockERC20} from "BoringSolidity/mocks/MockERC20.sol";

contract LockingMultiRewardsBase is BaseTest {
    using SafeTransferLib for address;

    LockingMultiRewards internal staking;
    address internal stakingToken;
    address internal token;
    address internal token2;

    function _setupReward(address rewardToken) internal {
        vm.startPrank(staking.owner());
        staking.setOperator(alice, true);
        staking.addReward(address(rewardToken));
        vm.stopPrank();
    }

    function _distributeReward(address rewardToken, uint256 amount) internal {
        vm.startPrank(alice);
        deal(rewardToken, alice, amount);
        rewardToken.safeApprove(address(staking), amount);
        staking.notifyRewardAmount(rewardToken, amount);
    }
}

contract LockingMultiRewardsAdvancedTest is LockingMultiRewardsBase {
    using SafeTransferLib for address;
    using LibPRNG for LibPRNG.PRNG;
    uint256 constant BIPS = 10_000;

    function setUp() public override {
        fork(ChainId.Arbitrum, 153716876);
        super.setUp();

        LockingMultiRewardsScript script = new LockingMultiRewardsScript();
        script.setTesting(true);

        (staking) = script.deployWithParameters(toolkit.getAddress(block.chainid, "mim"), 30_000, 1 weeks, 13 weeks, tx.origin);

        stakingToken = staking.stakingToken();
        token = toolkit.getAddress(block.chainid, "usdc");

        _setupReward(token);
    }

    function _getAPY() private view returns (uint256) {
        uint256 rewardsPerYear = staking.getRewardForDuration(token) * 52;
        uint256 totalSupply = staking.totalSupply(); // value is $1

        // apy in bips
        return (rewardsPerYear * BIPS) / totalSupply;
    }

    function testStakeSimpleWithLocking() public {
        uint256 amount = 10 ** 10;

        vm.startPrank(bob);
        deal(stakingToken, bob, 10 ** 15);
        uint256 initialBalance = stakingToken.balanceOf(bob);
        stakingToken.safeApprove(address(staking), amount);
        staking.stake(amount, true);

        // boosted amounts
        assertEq(staking.totalSupply(), amount * 3);
        assertEq(staking.balanceOf(bob), amount * 3);
        assertEq(stakingToken.balanceOf(bob), initialBalance - amount);
    }

    function testStakeSimpleWithAndWithoutLocking() public {
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

        // current block timestamp is:
        // Fri Nov 24 2023 20:57:09 UTC
        // next unlock date should be next thursday + 13 weeks
        // 30 november 2023 00:00:00 UTC + 13 weeks = 29 february 2024 00:00:00 UTC
        LockingMultiRewards.LockedBalance[] memory locks = staking.userLocks(bob);
        vm.warp(locks[0].unlockTime);
        assertEq(block.timestamp, 1709164800); // 29 february 2024 00:00:00 UTC

        address[] memory users = new address[](2);
        users[0] = bob;
        users[1] = alice;

        staking.processExpiredLocks(users);
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
        staking.processExpiredLocks(users);

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
            staking.processExpiredLocks(users);
            assertEq(staking.userLocks(bob).length, 12 - i);
            advanceTime(1 weeks);
        }
    }

    function testFuzzStaking(
        address[10] memory users,
        uint256[13][10] memory depositPerWeek,
        uint256[13][10] memory numDepositPerWeek,
        uint256 maxUsers
    ) public onlyProfile("ci") {
        maxUsers = bound(maxUsers, 1, users.length);
        LibPRNG.PRNG memory prng;
        prng.seed(8723489723489723); // some seed

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
            //_testFuzzStakingCheckApyAndRewards(users, maxUsers);

            advanceTime(1 weeks);
        }
    }

    function _testFuzzStakingStake(address user, uint256 amount, bool locking) private {
        LockingMultiRewards.Reward memory reward = staking.rewardData(token);
        uint256 previousRewardPerToken = reward.rewardPerTokenStored;
        uint256 previousLastUpdateTime = reward.lastUpdateTime;
        uint256 previousEarned = staking.earned(user, token);
        uint256 previousReward = staking.rewards(user, token);
        uint256 previousRewardPerTokenPaid = staking.userRewardPerTokenPaid(user, token);
        uint256 previousTotalSupply = staking.totalSupply();
        uint256 previousBalanceOf = staking.balanceOf(user);

        // since we advance 5 seconds between each deposit, we expect reward.lastUpdateTime to be stalled until stake is called
        assertLt(previousLastUpdateTime, block.timestamp, "previousLastUpdateTime should be less than block.timestamp");

        pushPrank(user);
        staking.stake(amount, locking);
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

    function _testFuzzStakingCheckLockingConsistency(address[10] memory users, uint256 numUsers) private {
        for (uint256 i = 0; i < numUsers; i++) {
            LockingMultiRewards.LockedBalance[] memory locks = staking.userLocks(users[i]);
            LockingMultiRewards.Balances memory balances = staking.balances(users[i]);

            uint256 totalLocked = 0;
            uint256 totalUnlocked = balances.unlocked;

            for (uint256 j = 0; j < locks.length; j++) {
                if (locks[j].unlockTime > block.timestamp) {
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

    // check that the APY is consistency with the number of users considering their boosted and unboosted balances,
    // the total supply and the reward per duration
    function _testFuzzStakingCheckApyAndRewards(address[10] memory users, uint256 numUsers) private {
        uint256 totalSupply = 0;
        uint256 totalUnlocked = 0;
        uint256 totalLocked = 0;
        uint256 totalBoosted = 0;
        uint256 totalUnboosted = 0;
        uint256 totalRewards = 0;

        for (uint256 i = 0; i < numUsers; i++) {
            uint256 unlocked = staking.unlocked(users[i]);
            uint256 locked = staking.locked(users[i]);
            uint256 boosted = staking.balanceOf(users[i]);

            assertEq(boosted, unlocked + (locked * 3));
            totalSupply += unlocked + (locked * 3);
        }

        //
        //uint256 expectedRewards = (rewardPerDuration * totalSupply) / BIPS;
        //assertApproxEqAbs(totalRewards, expectedRewards, 100);
    }
}

contract LockingMultiRewardsSimpleTest_Disabled is LockingMultiRewardsBase {
    using SafeTransferLib for address;

    function setUp() public override {
        fork(ChainId.Arbitrum, 153716876);
        super.setUp();

        LockingMultiRewardsScript script = new LockingMultiRewardsScript();
        script.setTesting(true);

        (staking) = script.deployWithParameters(toolkit.getAddress(block.chainid, "mim"), 30_000, 60 seconds, 1 weeks, tx.origin);

        stakingToken = staking.stakingToken();
        token = toolkit.getAddress(block.chainid, "arb");
        token2 = toolkit.getAddress(block.chainid, "spell");
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
        staking.notifyRewardAmount(address(0), 0);
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
        assertEq(token.balanceOf(bob), earnings);
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

        assertGt(staking.getRewardForDuration(address(token)), 0);
    }

    function testRewardCreationTransfersBalance() public {
        uint256 amount = 10 ** 10;
        _setupReward(token);
        _distributeReward(token, amount);
        assertEq(staking.rewardData(token).rewardRate, amount / 60);
        assertEq(staking.getRewardForDuration(token), (amount / 60) * 60);
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

        _setupReward(token);
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
}
