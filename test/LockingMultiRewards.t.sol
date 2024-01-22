// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/LockingMultiRewards.s.sol";
import {Address} from "openzeppelin-contracts/utils/Address.sol";
import {LockingMultiRewards} from "staking/LockingMultiRewards.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {MockERC20} from "BoringSolidity/mocks/MockERC20.sol";

contract LockingMultiRewardsTest is BaseTest {
    using SafeTransferLib for address;

    LockingMultiRewards staking;
    address stakingToken;
    address token;
    address token2;

    function setUp() public override {
        fork(ChainId.Arbitrum, 153716876);
        super.setUp();

        LockingMultiRewardsScript script = new LockingMultiRewardsScript();
        script.setTesting(true);

        (staking) = script.deploy();

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

    function testNotifyRewardBeforePeriodFinish() public {_setupReward(token);
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

    function _setupReward(address rewardToken) private {
        vm.startPrank(staking.owner());
        staking.setOperator(alice, true);
        staking.addReward(address(rewardToken));
        vm.stopPrank();
    }

    function _distributeReward(address rewardToken, uint256 amount) private {
        vm.startPrank(alice);
        deal(rewardToken, alice, amount);
        rewardToken.safeApprove(address(staking), amount);
        staking.notifyRewardAmount(rewardToken, amount);
    }
}
