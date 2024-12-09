// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/MultiRewards.s.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {MultiRewards, RewardHandlerParams} from "/staking/MultiRewards.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {MockERC20} from "@BoringSolidity/mocks/MockERC20.sol";
import {OwnableOperators} from "/mixins/OwnableOperators.sol";
import {MultiRewardsClaimingHandler, MultiRewardsClaimingHandlerParam} from "/periphery/MultiRewardsClaimingHandler.sol";
import {ILzOFTV2, ILzCommonOFT} from "@abracadabra-oftv2/interfaces/ILayerZero.sol";

contract MultiRewardsTest is BaseTest {
    using SafeTransferLib for address;

    MultiRewards staking;
    address stakingToken;
    address arb;
    address spell;

    MultiRewardsClaimingHandler rewardHandler;
    mapping(address => ILzOFTV2) ofts;

    function setUp() public override {
        fork(ChainId.Arbitrum, 255576134);
        super.setUp();

        staking = new MultiRewards(toolkit.getAddress("mim"), tx.origin);
        stakingToken = staking.stakingToken();
        arb = toolkit.getAddress("arb");
        spell = toolkit.getAddress("spellV2");
    }

    function setupRewardHandler() private {
        rewardHandler = new MultiRewardsClaimingHandler(address(this));

        pushPrank(staking.owner());
        staking.setRewardHandler(address(rewardHandler));
        popPrank();

        ofts[spell] = ILzOFTV2(toolkit.getAddress("spell.oftv2"));
        ofts[stakingToken] = ILzOFTV2(toolkit.getAddress("mim.oftv2"));

        rewardHandler.setOperator(address(staking), true);
        rewardHandler.setRewardInfo(arb, ILzOFTV2(address(0))); // ARB is not OFTv2
        rewardHandler.setRewardInfo(spell, ofts[spell]);
        rewardHandler.setRewardInfo(stakingToken, ofts[stakingToken]);
    }

    function testOnlyOwnerCanCall() public {
        vm.expectRevert(OwnableOperators.Unauthorized.selector);
        staking.addReward(address(0), 0);

        vm.expectRevert(OwnableOperators.Unauthorized.selector);
        staking.setRewardsDuration(address(0), 0);

        vm.expectRevert(OwnableOperators.Unauthorized.selector);
        staking.recover(address(0), 0);

        vm.expectRevert(OwnableOperators.Unauthorized.selector);
        staking.pause();

        vm.expectRevert(OwnableOperators.Unauthorized.selector);
        staking.unpause();
    }

    function testOnlyOperatorsCanCall() public {
        vm.startPrank(alice);
        vm.expectRevert(OwnableOperators.Unauthorized.selector);
        staking.notifyRewardAmount(address(0), 0);
    }

    function testDurationNotPriorSet() public {
        vm.startPrank(staking.owner());
        assertEq(staking.rewardData(address(arb)).rewardsDuration, 0);
        staking.addReward(address(arb), 60);
        assertEq(staking.rewardData(address(arb)).rewardsDuration, 60);
    }

    function testRewardPerTokenZeroSupply() public {
        vm.startPrank(staking.owner());
        staking.addReward(address(arb), 60);
        assertEq(staking.rewardPerToken(address(arb)), 0);
    }

    function testNotPaused() public view {
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

    function testCannotSetDurationZero() public {
        vm.startPrank(staking.owner());
        vm.expectRevert(abi.encodeWithSignature("ErrZeroDuration()"));
        staking.setRewardsDuration(arb, 0);
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
        _setupReward(arb, 60);
        _distributeReward(arb, 10 ether);

        vm.startPrank(bob);
        deal(stakingToken, bob, 100 ether);
        uint256 amount = stakingToken.balanceOf(bob);
        assertEq(stakingToken.balanceOf(bob), amount);
        stakingToken.safeApprove(address(staking), amount);
        staking.stake(amount);
        assertEq(stakingToken.balanceOf(bob), 0);
        assertEq(staking.balanceOf(bob), amount);
        assertEq(staking.earned(bob, arb), 0);

        advanceTime(100 seconds);

        uint256 earnings = staking.earned(bob, arb);
        assertGt(earnings, 0);

        staking.exit();
        assertEq(stakingToken.balanceOf(bob), amount);
        assertEq(staking.balanceOf(bob), 0);
        assertEq(staking.earned(bob, arb), 0);
        assertEq(arb.balanceOf(bob), earnings);
    }

    function testUnstakedRevertsOnExit() public {
        assertEq(staking.balanceOf(bob), 0);
        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSignature("ErrZeroAmount()"));
        staking.exit();
    }

    function testNoLastTimeReward() public {
        vm.startPrank(staking.owner());
        staking.grantRoles(alice, staking.ROLE_OPERATOR());
        staking.addReward(address(arb), 60);
        vm.stopPrank();
        assertEq(staking.lastTimeRewardApplicable(address(arb)), 0);
    }

    function testRewardDurationUpdates() public {
        _setupReward(arb, 60);
        _distributeReward(arb, 10 ether);

        assertGt(staking.getRewardForDuration(address(arb)), 0);
    }

    function testRewardPeriodFinish() public {
        _setupReward(arb, 60);
        _distributeReward(arb, 10 ether);

        vm.startPrank(staking.owner());
        vm.expectRevert(abi.encodeWithSignature("ErrRewardPeriodStillActive()"));
        staking.setRewardsDuration(arb, 10 days);
    }

    function testUpdateRewardDuration() public {
        _setupReward(arb, 60);
        advanceTime(100);

        vm.startPrank(staking.owner());
        staking.setRewardsDuration(arb, 1000);
        assertEq(staking.rewardData(arb).rewardsDuration, 1000);
    }

    function testRewardCreationTransfersBalance() public {
        uint256 amount = 10 ** 10;
        _setupReward(arb, 60);
        _distributeReward(arb, amount);
        assertEq(staking.rewardData(arb).rewardRate, amount / 60);
        assertEq(staking.getRewardForDuration(arb), (amount / 60) * 60);
    }

    function testLastTimeRewardApplicable() public {
        uint256 rewardAmount = 10 ** 15;
        _setupReward(arb, 60);
        uint256 lastTime = staking.lastTimeRewardApplicable(arb);
        uint256 currentTime;

        for (uint256 i = 0; i < 5; i++) {
            _distributeReward(arb, rewardAmount);
            advanceTime(60);
            currentTime = staking.lastTimeRewardApplicable(arb);
            assertGt(currentTime, lastTime);
            lastTime = currentTime;
        }
    }

    function testUpdateRewardDurationNonInterferance() public {
        _setupReward(arb, 60);
        _setupReward(spell, 2630000);

        uint256 rewardLength = staking.rewardData(arb).rewardsDuration;
        uint256 slowLength = staking.rewardData(spell).rewardsDuration;

        assertGt(rewardLength, 0);
        assertGt(slowLength, 0);

        advanceTime(100);

        vm.startPrank(staking.owner());
        staking.setRewardsDuration(arb, 10000);

        assertEq(staking.rewardData(arb).rewardsDuration, 10000);
        assertEq(staking.rewardData(spell).rewardsDuration, slowLength);
    }

    function testNotifyRewardBeforePeriodFinish() public {
        uint256 rewardAmount = 10 ** 15;

        _setupReward(arb, 60);
        _distributeReward(arb, rewardAmount);

        uint256 initialRate = rewardAmount / 60;
        assertEq(staking.rewardData(arb).rewardRate, initialRate);

        _distributeReward(arb, rewardAmount);
        assertGt(staking.rewardData(arb).rewardRate, initialRate);

        advanceTime(1000);
        _distributeReward(arb, rewardAmount);
        assertEq(staking.rewardData(arb).rewardRate, initialRate);

        vm.expectRevert(abi.encodeWithSignature("ErrRewardPeriodStillActive()"));
        _distributeReward(arb, rewardAmount);
    }

    function testRewardPerTokenUpdates() public {
        uint256 amount = 10 ** 10;

        _setupReward(arb, 60);
        _distributeReward(arb, amount);

        vm.startPrank(bob);
        deal(stakingToken, bob, amount);
        stakingToken.safeApprove(address(staking), amount);
        staking.stake(amount);

        advanceTime(100);
        assertGt(staking.rewardPerToken(address(arb)), 0);
    }

    function testStakeBalanceOf() public {
        vm.startPrank(bob);
        deal(stakingToken, bob, 100 ether);
        stakingToken.safeApprove(address(staking), 100 ether);
        staking.stake(100 ether);
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
            _setupReward(rewards[i], 60);
            _distributeReward(rewards[i], 10 ether);

            pushPrank(accounts[i]);
            deal(stakingToken, accounts[i], 10000);
            stakingToken.safeApprove(address(staking), 10000);
            staking.stake(10000);
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
        staking.stake(amount);

        assertEq(staking.totalSupply(), amount);
        assertEq(staking.balanceOf(bob), amount);
        assertEq(stakingToken.balanceOf(bob), initialBalance - amount);
    }

    function testWithdrawMultiples() public {
        uint256 amount = 10 ** 10;
        _setupReward(arb, 2630000);
        _distributeReward(arb, 10 ** 19);

        pushPrank(bob);
        deal(stakingToken, bob, amount);
        stakingToken.safeApprove(address(staking), amount);
        staking.stake(amount);
        popPrank();

        pushPrank(carol);
        deal(stakingToken, carol, amount * 10);
        stakingToken.safeApprove(address(staking), amount * 10);
        staking.stake(amount * 10);
        popPrank();

        advanceTime(60 * 60);

        uint256 bobEarnings = staking.earned(bob, arb);
        assertGt(bobEarnings, 0);

        uint256 bobInitialBalance = stakingToken.balanceOf(bob);
        uint256 bobInitialRewardBalance = arb.balanceOf(bob);

        uint256 carolEarnings = staking.earned(carol, arb);
        assertGt(carolEarnings, 0);

        uint256 carolInitialBalance = stakingToken.balanceOf(carol);
        uint256 carolInitialRewardBalance = arb.balanceOf(carol);

        // assert earn_b * 0.99 <= earn_c // 10 <= earn_b * 1.01
        assertGe(carolEarnings, (bobEarnings * 99) / 100);

        pushPrank(bob);
        staking.exit();
        uint256 bobFinalRewardGain = arb.balanceOf(bob) - bobInitialRewardBalance;
        uint256 bobFinalBaseGain = stakingToken.balanceOf(bob) - bobInitialBalance;
        popPrank();

        pushPrank(carol);
        staking.exit();
        uint256 carolFinalRewardGain = arb.balanceOf(carol) - carolInitialRewardBalance;
        uint256 carolFinalBaseGain = stakingToken.balanceOf(carol) - carolInitialBalance;
        popPrank();

        // assert multi.balanceOf(carol) / 10 == multi.balanceOf(bob)
        assertEq(staking.balanceOf(carol), staking.balanceOf(bob) * 10);

        // assert (bob_final_reward_gain * 0.99 <= carol_final_reward_gain / 10 <= bob_final_reward_gain * 1.01)
        assertLe((bobFinalRewardGain * 99) / 100, carolFinalRewardGain);
        assertLe(carolFinalRewardGain / 10, (bobFinalRewardGain * 101) / 100);

        // assert carol_final_base_gain / 10 == bob_final_base_gain
        assertEq(carolFinalBaseGain / 10, bobFinalBaseGain);
    }

    function testDifferentRewardAmounts() public {
        uint256 amount = 10 ** 12;

        _setupReward(arb, 60);
        _distributeReward(arb, 10 ** 15);
        _setupReward(spell, 60);
        _distributeReward(spell, 10 ** 14);

        pushPrank(bob);
        deal(stakingToken, bob, amount);
        stakingToken.safeApprove(address(staking), amount);
        staking.stake(amount);

        advanceTime(1000);
        uint256 reward1Earning = staking.earned(bob, arb);
        uint256 reward2Earning = staking.earned(bob, spell);

        uint256 initialStakingBalance = stakingToken.balanceOf(bob);
        uint256 initialReward1Balance = arb.balanceOf(bob);
        uint256 initialReward2Balance = spell.balanceOf(bob);

        staking.exit();
        popPrank();

        uint256 finalStakingGain = stakingToken.balanceOf(bob) - initialStakingBalance;
        uint256 finalReward1Gain = arb.balanceOf(bob) - initialReward1Balance;
        uint256 finalReward2Gain = spell.balanceOf(bob) - initialReward2Balance;

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
        staking.stake(100 ether);
        vm.expectRevert();
        staking.withdraw(101 ether);
    }

    function testCannotWithdrawMoreThanDepositIfBalanceExists() public {
        pushPrank(bob);
        deal(stakingToken, bob, 100 ether);
        stakingToken.safeApprove(address(staking), 100 ether);
        staking.stake(100 ether);
        popPrank();

        pushPrank(carol);
        deal(stakingToken, carol, 100 ether);
        stakingToken.safeApprove(address(staking), 100 ether);
        staking.stake(100 ether);
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
        staking.stake(amount);

        uint256 initialSupply = staking.totalSupply();
        uint256 initialBalance = staking.balanceOf(bob);
        uint256 withdrawAmount = amount / 3;
        staking.withdraw(withdrawAmount);

        assertEq(staking.totalSupply(), initialSupply - withdrawAmount);
        assertEq(staking.balanceOf(bob), initialBalance - withdrawAmount);
        assertEq(stakingToken.balanceOf(bob), withdrawAmount);
    }

    function testDepletedRewards() public {
        _setupReward(arb, 30 days);

        pushPrank(bob);
        deal(stakingToken, bob, 100 ether);
        stakingToken.safeApprove(address(staking), 100 ether);
        staking.stake(100 ether);
        popPrank();

        _distributeReward(arb, 10 ether);

        advanceTime(60 days);
        pushPrank(bob);
        uint256 rewardsAmountBefore = arb.balanceOf(bob);
        staking.getRewards();
        assertGt(arb.balanceOf(bob), rewardsAmountBefore);
        rewardsAmountBefore = arb.balanceOf(bob);
        staking.getRewards();
        assertEq(arb.balanceOf(bob), rewardsAmountBefore);
        popPrank();

        pushPrank(carol);
        deal(stakingToken, carol, 100 ether);
        stakingToken.safeApprove(address(staking), 100 ether);
        staking.stake(100 ether);
        popPrank();

        advanceTime(60 days);

        pushPrank(carol);
        rewardsAmountBefore = arb.balanceOf(carol);
        staking.getRewards();
        assertEq(arb.balanceOf(carol), rewardsAmountBefore);
        staking.getRewards();
        popPrank();

        _distributeReward(arb, 1 ether);

        pushPrank(carol);
        rewardsAmountBefore = arb.balanceOf(carol);
        staking.getRewards();
        assertEq(arb.balanceOf(carol), rewardsAmountBefore);
        staking.getRewards();
        popPrank();

        advanceTime(60 days);
        pushPrank(carol);
        rewardsAmountBefore = arb.balanceOf(carol);
        staking.getRewards();
        assertGt(arb.balanceOf(carol), rewardsAmountBefore);
        staking.getRewards();
        popPrank();

        pushPrank(bob);
        rewardsAmountBefore = arb.balanceOf(bob);
        staking.getRewards();
        assertGt(arb.balanceOf(bob), rewardsAmountBefore);
        staking.getRewards();
        popPrank();
    }

    function testSettingRewardHandlerWithoutUsingIt() public {
        setupRewardHandler();

        uint256 amount = 100 ether;
        _setupReward(arb, 60);
        _distributeReward(arb, 10 ether);

        vm.startPrank(bob);
        deal(stakingToken, bob, amount);
        stakingToken.safeApprove(address(staking), amount);
        staking.stake(amount);

        advanceTime(30);

        uint256 earned = staking.earned(bob, arb);
        assertGt(earned, 0, "Should have earned rewards");

        uint256 bobBalanceBefore = arb.balanceOf(bob);
        staking.getRewards();
        uint256 bobBalanceAfter = arb.balanceOf(bob);

        assertEq(bobBalanceAfter - bobBalanceBefore, earned, "Should have received correct reward amount locally");
    }

    function testRewardHandlerBridging() public {
        setupRewardHandler();

        uint256 amount = 100 ether;
        _setupReward(spell, 60);
        _distributeReward(spell, 10 ether);

        vm.startPrank(bob);
        deal(stakingToken, bob, amount);
        stakingToken.safeApprove(address(staking), amount);
        staking.stake(amount);

        advanceTime(30);

        uint256 earned = staking.earned(bob, spell);
        assertGt(earned, 0, "Should have earned rewards");

        uint16 dstChainId = LayerZeroChainId.Mainnet;
        (uint256 fee, uint256 gas, MultiRewardsClaimingHandlerParam memory param) = rewardHandler.estimateBridgingFee(spell, dstChainId);

        MultiRewardsClaimingHandlerParam[] memory params = new MultiRewardsClaimingHandlerParam[](1);
        params[0] = MultiRewardsClaimingHandlerParam({fee: uint128(fee), gas: uint112(gas), dstChainId: dstChainId});
        MultiRewardsClaimingHandlerParam[] memory params2 = new MultiRewardsClaimingHandlerParam[](1);
        params2[0] = param;

        bytes memory encodedData = abi.encode(params);
        bytes memory encodedData2 = abi.encode(params2);
        assertEq(encodedData, encodedData2, "Encoded data should be equal");

        MultiRewardsClaimingHandlerParam[] memory decodedParams = abi.decode(encodedData, (MultiRewardsClaimingHandlerParam[]));
        assertEq(decodedParams.length, 1, "Should have one param");
        assertEq(decodedParams[0].fee, fee, "Fee should match");
        assertEq(decodedParams[0].gas, gas, "Gas should match");
        assertEq(decodedParams[0].dstChainId, dstChainId, "Destination chain ID should match");

        vm.deal(bob, fee);
        staking.getRewards{value: fee}(bob, RewardHandlerParams({value: fee, data: encodedData}));
        
        vm.stopPrank();
    }

    function xtestMultipleRewardsBridging() public {
        setupRewardHandler();

        uint256 amount = 100 ether;
        _setupReward(arb, 60);
        _setupReward(spell, 60);
        _distributeReward(arb, 10 ether);
        _distributeReward(spell, 5 ether);

        vm.startPrank(bob);
        deal(stakingToken, bob, amount);
        stakingToken.safeApprove(address(staking), amount);
        staking.stake(amount);

        advanceTime(30);

        uint256 earnedArb = staking.earned(bob, arb);
        uint256 earnedSpell = staking.earned(bob, spell);
        assertGt(earnedArb, 0, "Should have earned rewards from ARB");
        assertGt(earnedSpell, 0, "Should have earned rewards from SPELL");

        uint16 dstChainId = 2;
        (uint256 fee, uint256 gas, ) = rewardHandler.estimateBridgingFee(spell, dstChainId);

        bytes memory combinedData = abi.encode(
            [
                MultiRewardsClaimingHandlerParam({fee: 0, gas: 0, dstChainId: 0}), // ARB (local transfer)
                MultiRewardsClaimingHandlerParam({fee: uint128(fee), gas: uint112(gas), dstChainId: dstChainId}) // SPELL
            ]
        );

        vm.deal(bob, fee);
        staking.getRewards{value: fee}(bob, RewardHandlerParams({value: fee, data: combinedData}));

        // Verify that ARB rewards were transferred locally
        assertEq(arb.balanceOf(bob), earnedArb, "ARB rewards should be transferred locally");

        // Verify that SPELL rewards were sent to the OFT contract
        assertEq(spell.balanceOf(address(ofts[spell])), earnedSpell, "SPELL rewards should be sent to OFT contract");

        // Simulate the OFT bridging for SPELL
        //MockLzOFTV2(address(ofts[spell])).simulateBridging(bob, earnedSpell);

        vm.stopPrank();
    }

    function xtestStakingTokenAsReward() public {
        setupRewardHandler();

        uint256 amount = 100 ether;
        _setupReward(stakingToken, 60);
        _distributeReward(stakingToken, 10 ether);

        vm.startPrank(bob);
        deal(stakingToken, bob, amount);
        stakingToken.safeApprove(address(staking), amount);
        staking.stake(amount);

        advanceTime(30);

        uint256 earned = staking.earned(bob, stakingToken);
        assertGt(earned, 0, "Should have earned rewards");

        uint16 dstChainId = 2;
        (uint256 fee, uint256 gas, ) = rewardHandler.estimateBridgingFee(stakingToken, dstChainId);

        vm.deal(bob, fee);
        staking.getRewards{value: fee}(
            bob,
            RewardHandlerParams({
                value: fee,
                data: abi.encode([MultiRewardsClaimingHandlerParam({fee: uint128(fee), gas: uint112(gas), dstChainId: dstChainId})])
            })
        );

        // Verify that the rewards were sent to the OFT contract
        assertEq(stakingToken.balanceOf(address(ofts[stakingToken])), earned, "Rewards should be sent to OFT contract");

        // Simulate the OFT bridging
        //MockLzOFTV2(address(ofts[stakingToken])).simulateBridging(bob, earned);

        vm.stopPrank();
    }

    function _setupReward(address rewardToken, uint256 duration) private {
        vm.startPrank(staking.owner());
        staking.grantRoles(alice, staking.ROLE_OPERATOR());
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
