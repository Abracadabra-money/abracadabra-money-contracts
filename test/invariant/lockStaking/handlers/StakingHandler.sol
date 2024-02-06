// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import {BaseHandler} from "./BaseHandler.sol";
import {LockingMultiRewards} from "staking/LockingMultiRewards.sol";
import {MockERC20} from "BoringSolidity/mocks/MockERC20.sol";
import {TimestampStore} from "../stores/TimestampStore.sol";
import "forge-std/console.sol";

/// @dev This contract is exposed to Foundry for invariant testing.
contract StakingHandler is BaseHandler {
    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    LockingMultiRewards public staking;
    address public operator;
    uint256 constant NO_MINIMUM = 0;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    constructor(
        address token_,
        TimestampStore timestampStore_,
        LockingMultiRewards staking_,
        address operator_
    ) BaseHandler(MockERC20(token_), timestampStore_) {
        staking = staking_;
        operator = operator_;
    }

    /*//////////////////////////////////////////////////////////////////////////
                               LockingMultiRewards
    //////////////////////////////////////////////////////////////////////////*/

    function stake(
        uint256 amount,
        bool _lock,
        uint256 actorIndexSeed,
        uint256 timeJumpSeed
    ) public useActor(actorIndexSeed) adjustTimestamp(timeJumpSeed) {
        // PRE-CONDITIONS
        amount = bound(amount, 1, 100_000 ether);
        deal(address(token), currentActor, amount);
        token.approve(address(staking), amount);

        uint256 beforeSupply = staking.totalSupply();
        uint256 beforeUserStakingBalance = staking.balanceOf(currentActor);
        uint256 beforeUserTokenBalance = token.balanceOf(currentActor);

        // ACTION
        (bool success, ) = address(staking).call(abi.encodeWithSelector(staking.stake.selector, amount, _lock));

        // POST-CONDITIONS
        if (success) {
            uint256 afterSupply = staking.totalSupply();
            uint256 afterUserStakingBalance = staking.balanceOf(currentActor);
            uint256 afterUserTokenBalance = token.balanceOf(currentActor);

            assertEq(
                afterSupply,
                !_lock ? beforeSupply + amount : beforeSupply + 3 * amount,
                "Total supply not increased correctly after staking."
            );
            assertEq(
                afterUserStakingBalance,
                !_lock ? beforeUserStakingBalance + amount : beforeUserStakingBalance + amount * 3,
                "User staking balance not increased correctly after staking."
            );
            assertEq(
                afterUserTokenBalance + amount,
                beforeUserTokenBalance,
                "User staking token balance not decremented correctly after staking."
            );
        }
    }

    function lock(
        uint256 amount,
        uint256 actorIndexSeed,
        uint256 timeJumpSeed
    ) public useActor(actorIndexSeed) adjustTimestamp(timeJumpSeed) {
        // PRE-CONDITIONS
        amount = bound(amount, 0, staking.unlocked(currentActor));
        uint256 beforeSupply = staking.totalSupply();
        uint256 beforeUserStakingBalance = staking.balanceOf(currentActor);
        uint256 beforeUserTokenBalance = token.balanceOf(currentActor);

        // ACTION
        (bool success, ) = address(staking).call(abi.encodeWithSelector(staking.lock.selector, amount));
        // POST-CONDITIONS
        if (success) {
            uint256 afterSupply = staking.totalSupply();
            uint256 afterUserStakingBalance = staking.balanceOf(currentActor);
            uint256 afterUserTokenBalance = token.balanceOf(currentActor);
            assertEq(afterSupply, beforeSupply + 3 * amount - amount, "Total supply not increased correctly after locking.");
            assertEq(
                afterUserStakingBalance,
                beforeUserStakingBalance + amount * 3 - amount,
                "User staking balance not increased correctly after locking."
            );
            assertEq(afterUserTokenBalance, beforeUserTokenBalance, "User token balance changed upon locking.");
        }
    }

    function withdraw(
        uint256 amount,
        uint256 actorIndexSeed,
        uint256 timeJumpSeed
    ) public useActor(actorIndexSeed) adjustTimestamp(timeJumpSeed) {
        // PRE-CONDITIONS
        amount = bound(amount, 0, staking.unlocked(currentActor));
        uint256 beforeUnlocked = staking.unlocked(currentActor);
        uint256 beforeUserStakingBalance = staking.balanceOf(currentActor);
        uint256 beforeUserTokenBalance = token.balanceOf(currentActor);

        // ACTION
        (bool success, ) = address(staking).call(abi.encodeWithSelector(staking.withdraw.selector, amount));

        // POST-CONDITIONS
        if (success) {
            uint256 afterUnlocked = staking.unlocked(currentActor);
            uint256 afterUserStakingBalance = staking.balanceOf(currentActor);
            uint256 afterUserTokenBalance = token.balanceOf(currentActor);

            assertEq(afterUnlocked + amount, beforeUnlocked, "Unlocked Delta != Amount Withdrawn");
            assertEq(afterUserStakingBalance + amount, beforeUserStakingBalance, "Staking Balance Delta != Amount Withdrawn");
            assertEq(afterUserTokenBalance, beforeUserTokenBalance + amount, "User Token Balance Delta != Amount Withdrawn");
        }
    }

    function getRewards(uint256 actorIndexSeed) public useActor(actorIndexSeed) useCurrentTimestamp {
        // PRE-CONDITIONS
        uint256 beforeUserTokenBalance = token.balanceOf(currentActor);
        uint256 beforeRewards = staking.rewards(currentActor, address(token));
        uint256 beforeTotalSupply = staking.totalSupply();

        // ACTION
        staking.getRewards();

        // POST-CONDITIONS
        uint256 afterUserTokenBalance = token.balanceOf(currentActor);
        uint256 afterRewards = staking.rewards(currentActor, address(token));
        uint256 afterTotalSupply = staking.totalSupply();
        //uint256 afterUserEarned = staking.earned(currentActor, address(token));
        //uint256 afterStakingBalance = staking.balanceOf(currentActor);

        assertEq(afterUserTokenBalance, beforeUserTokenBalance + beforeRewards, "Balance Delta != Rewards");
        assertEq(afterRewards, 0, "Rewards After Claiming != 0");
        assertEq(beforeTotalSupply, afterTotalSupply, "Total Supply Changed After Claiming Rewards");
    }

    /*//////////////////////////////////////////////////////////////////////////
                              Operators
    //////////////////////////////////////////////////////////////////////////*/

    function notifyReward(uint256 amount) public useCurrentTimestamp {
        if (!staking.rewardData(address(token)).exists) {
            return;
        }

        amount = bound(amount, staking.rewardsDuration(), 10_000_000 ether);
        vm.startPrank(operator);
        deal(address(token), operator, amount);
        token.approve(address(staking), amount);
        staking.notifyRewardAmount(address(token), amount, NO_MINIMUM);
        vm.stopPrank();
    }

    // function processExpiredLocks(uint256 lockIndex) public useCurrentTimestamp {
    //     uint256[] memory newLockIndexes = new uint256[](actors.length);
    //     for(uint i = 0; i < actors.length; i++) {
    //         lockIndex = _random(0, staking.userLocksLength(actors[i]));
    //         newLockIndexes[i] = lockIndex;
    //         console.log("Lock index:", lockIndex);
    //     }

    //     vm.startPrank(operator);
    //    (bool success, ) = address(staking).call(abi.encodeWithSelector(staking.processExpiredLocks.selector, actors, newLockIndexes));
    //     vm.stopPrank();
    // }

    function processExpiredLocks(uint256 actorIndexSeed) public useActor(actorIndexSeed) useCurrentTimestamp {
        uint256[] memory newLockIndexes = new uint256[](1);
        address[] memory actors = new address[](1);
        uint256 lockIndex = _random(0, staking.userLocksLength(currentActor));

        newLockIndexes[0] = lockIndex;
        actors[0] = currentActor;

        vm.startPrank(operator);

        /// solhint-disable-next-line avoid-low-level-calls unused-vars
        (bool success, ) = address(staking).call(abi.encodeWithSelector(staking.processExpiredLocks.selector, actors, newLockIndexes));

        if (success) {}
        vm.stopPrank();
    }
}
