// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {BaseTest, ChainId} from "utils/BaseTest.sol";
import {TokenBankScript} from "script/TokenBank.s.sol";
import {TokenBank} from "staking/TokenBank.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

contract TokenBankTest is BaseTest {
    using SafeTransferLib for address;

    event LogDeposit(address indexed user, uint256 amount, uint256 unlockTime, uint256 lockCount);
    event LogClaimed(address indexed user, uint256 amount);

    TokenBank oSpellBank;
    address spell;
    address oSpell;

    function setUp() public override {
        fork(ChainId.Arbitrum, 215580131);
        super.setUp();

        TokenBankScript script = new TokenBankScript();
        script.setTesting(true);

        (oSpellBank) = script.deploy();

        spell = oSpellBank.underlyingToken();
        oSpell = oSpellBank.asset();

        assertEq(oSpellBank.maxLocks(), 13);
    }

    function testDepositZeroAmount() public {
        vm.expectRevert(TokenBank.ErrZeroAmount.selector);
        oSpellBank.deposit(0, block.timestamp);
    }

    function testMint() public {
        _mintOSpell(1000 ether, alice);
        assertEq(oSpell.balanceOf(address(alice)), 1000 ether);
    }

    function testDeposit() public {
        _mintOSpell(1000 ether, alice);

        pushPrank(alice);
        oSpellBank.deposit(1000 ether, block.timestamp);
        assertEq(oSpell.balanceOf(address(alice)), 0);
        assertEq(spell.balanceOf(address(alice)), 0);

        // checks lock
        TokenBank.LockedBalance[] memory locks = oSpellBank.userLocks(alice);
        assertEq(locks.length, 1);
        assertEq(locks[0].amount, 1000 ether);
        assertEq(locks[0].unlockTime, oSpellBank.nextUnlockTime());

        vm.warp(oSpellBank.nextUnlockTime() + 1);
        oSpellBank.claim();
        assertEq(spell.balanceOf(address(alice)), 1000 ether);
        assertEq(oSpell.balanceOf(address(alice)), 0);

        locks = oSpellBank.userLocks(alice);
        assertEq(locks.length, 0);
        popPrank();
    }

    function testDepositAndClaimSingleLock() public {
        _mintOSpell(2000 ether, alice);

        pushPrank(alice);
        vm.expectEmit(true, true, true, true);
        emit LogDeposit(alice, 1000 ether, oSpellBank.nextUnlockTime(), 1);
        oSpellBank.deposit(1000 ether, block.timestamp + 100);
        assertEq(oSpell.balanceOf(address(alice)), 1000 ether);

        vm.expectEmit(true, true, true, true);
        emit LogDeposit(alice, 1000 ether, oSpellBank.nextUnlockTime(), 1);
        oSpellBank.deposit(1000 ether, block.timestamp + 200);
        assertEq(oSpell.balanceOf(address(alice)), 0);

        TokenBank.LockedBalance[] memory locks = oSpellBank.userLocks(alice);
        assertEq(locks.length, 1);
        assertEq(locks[0].amount, 2000 ether);
        assertEq(locks[0].unlockTime, oSpellBank.nextUnlockTime());

        vm.warp(oSpellBank.nextUnlockTime() + 1);

        vm.expectEmit(true, true, true, true);
        emit LogClaimed(alice, 2000 ether);
        oSpellBank.claim();
        assertEq(spell.balanceOf(address(alice)), 2000 ether);
        assertEq(oSpell.balanceOf(address(alice)), 0);

        locks = oSpellBank.userLocks(alice);
        assertEq(locks.length, 0);
        popPrank();
    }

    function testMaxUserLocksExceeded() public {
        _mintOSpell(100_000 ether, alice);

        pushPrank(alice);
        for (uint256 i = 0; i < oSpellBank.maxLocks(); i++) {
            vm.expectEmit(true, true, true, true);
            emit LogDeposit(alice, 1000 ether, oSpellBank.nextUnlockTime(), i + 1);
            oSpellBank.deposit(1000 ether, block.timestamp);
            advanceTime(oSpellBank.EPOCH_DURATION());
        }

        vm.expectRevert(TokenBank.ErrMaxUserLocksExceeded.selector);
        oSpellBank.deposit(1000 ether, block.timestamp);
        popPrank();
    }

    function testInvalidLockDuration() public {
        address owner = oSpellBank.owner();

        pushPrank(owner);
        vm.expectRevert(TokenBank.ErrInvalidLockDuration.selector);
        new TokenBank(address(oSpell), address(spell), 1 days, owner);

        vm.expectRevert(TokenBank.ErrInvalidDurationRatio.selector);
        new TokenBank(address(oSpell), address(spell), 8 days, owner);
        popPrank();
    }

    function testExpiredLockingDeadline() public {
        _mintOSpell(1000 ether, alice);

        pushPrank(alice);
        vm.expectRevert(TokenBank.ErrExpired.selector);
        oSpellBank.deposit(1000 ether, block.timestamp - 1);
        popPrank();
    }

    function testPauseAndUnpause() public {
        address owner = oSpellBank.owner();

        pushPrank(owner);
        oSpellBank.pause();
        vm.expectRevert("Pausable: paused");
        oSpellBank.deposit(1000 ether, block.timestamp + 100);

        oSpellBank.unpause();
        _mintOSpell(1000 ether, alice);
        popPrank();

        pushPrank(alice);
        vm.expectEmit(true, true, true, true);
        emit LogDeposit(alice, 1000 ether, oSpellBank.nextUnlockTime(), 1);
        oSpellBank.deposit(1000 ether, block.timestamp + 100);
        assertEq(oSpell.balanceOf(address(alice)), 0);
        popPrank();
    }

    /**
     * @dev Test that a claim returns 0 if there are no unlockable tokens.
     */
    function testClaimingWithNoUnlocks() public {
        _mintOSpell(1000 ether, alice);

        pushPrank(alice);
        oSpellBank.deposit(1000 ether, block.timestamp + 100);
        uint256 claimable = oSpellBank.claim();
        assertEq(claimable, 0);
        popPrank();
    }

    /**
     * @dev Test partial claims when only some of the deposited tokens are unlocked.
     */
    function testClaimPartialUnlock() public {
        _mintOSpell(2000 ether, alice);

        pushPrank(alice);
        oSpellBank.deposit(1000 ether, block.timestamp);
        uint256 firstLockExpiredAt = oSpellBank.nextUnlockTime();
        advanceTime(oSpellBank.EPOCH_DURATION());
        oSpellBank.deposit(1000 ether, block.timestamp);
        uint256 secondLockExpiredAt = oSpellBank.nextUnlockTime();
        TokenBank.LockedBalance[] memory locks = oSpellBank.userLocks(alice);
        assertEq(locks.length, 2);

        vm.warp(firstLockExpiredAt);
        vm.expectEmit(true, true, true, true);
        emit LogClaimed(alice, 1000 ether);
        uint256 claimable = oSpellBank.claim();
        assertEq(claimable, 1000 ether);
        assertEq(spell.balanceOf(address(alice)), 1000 ether);
        assertEq(oSpell.balanceOf(address(alice)), 0);

        locks = oSpellBank.userLocks(alice);
        assertEq(locks.length, 1);
        assertEq(locks[0].amount, 1000 ether);
        assertEq(locks[0].unlockTime, secondLockExpiredAt);

        vm.warp(secondLockExpiredAt + 1);

        vm.expectEmit(true, true, true, true);
        emit LogClaimed(alice, 1000 ether);
        claimable = oSpellBank.claim();
        assertEq(claimable, 1000 ether);
        assertEq(spell.balanceOf(address(alice)), 2000 ether);
        assertEq(oSpell.balanceOf(address(alice)), 0);

        locks = oSpellBank.userLocks(alice);
        assertEq(locks.length, 0);
        popPrank();
    }

    /**
     * @dev Test claims with multiple deposits and staggered unlock times.
     */
    function testClaimWithMultipleDepositsAndUnlocks() public {
        _mintOSpell(3000 ether, alice);

        pushPrank(alice);
        oSpellBank.deposit(1000 ether, block.timestamp);
        advanceTime(oSpellBank.EPOCH_DURATION());
        oSpellBank.deposit(1000 ether, block.timestamp);
        advanceTime(oSpellBank.EPOCH_DURATION());
        oSpellBank.deposit(1000 ether, block.timestamp);

        TokenBank.LockedBalance[] memory locks = oSpellBank.userLocks(alice);
        assertEq(locks.length, 3);

        vm.warp(locks[0].unlockTime);
        vm.expectEmit(true, true, true, true);
        emit LogClaimed(alice, 1000 ether);
        uint256 claimable = oSpellBank.claim();
        assertEq(claimable, 1000 ether);
        assertEq(spell.balanceOf(address(alice)), 1000 ether);

        locks = oSpellBank.userLocks(alice);
        assertEq(locks.length, 2);
        vm.warp(locks[1].unlockTime);

        vm.expectEmit(true, true, true, true);
        emit LogClaimed(alice, 1000 ether);
        claimable = oSpellBank.claim();
        assertEq(claimable, 1000 ether);
        assertEq(spell.balanceOf(address(alice)), 2000 ether);

        locks = oSpellBank.userLocks(alice);
        assertEq(locks.length, 1);
        vm.warp(locks[0].unlockTime);

        vm.expectEmit(true, true, true, true);
        emit LogClaimed(alice, 1000 ether);
        claimable = oSpellBank.claim();
        assertEq(claimable, 1000 ether);
        assertEq(spell.balanceOf(address(alice)), 3000 ether);
        assertEq(oSpell.balanceOf(address(alice)), 0);

        locks = oSpellBank.userLocks(alice);
        assertEq(locks.length, 0);
        popPrank();
    }

    /**
     * @dev Ensure claims by one user do not affect another user's locked tokens.
     */
    function testClaimingDoesNotAffectOtherUsers() public {
        _mintOSpell(2000 ether, alice);
        _mintOSpell(1000 ether, bob);

        pushPrank(alice);
        oSpellBank.deposit(2000 ether, block.timestamp);
        popPrank();

        pushPrank(bob);
        oSpellBank.deposit(1000 ether, block.timestamp);
        popPrank();

        advanceTime(oSpellBank.nextUnlockTime());

        pushPrank(bob);
        vm.expectEmit(true, true, true, true);
        emit LogClaimed(bob, 1000 ether);
        uint256 claimable = oSpellBank.claim();
        assertEq(claimable, 1000 ether);
        assertEq(spell.balanceOf(address(bob)), 1000 ether);
        assertEq(oSpell.balanceOf(address(bob)), 0);
        popPrank();

        pushPrank(alice);
        vm.expectEmit(true, true, true, true);
        emit LogClaimed(alice, 2000 ether);
        claimable = oSpellBank.claim();
        assertEq(claimable, 2000 ether);
        assertEq(spell.balanceOf(address(alice)), 2000 ether);
        assertEq(oSpell.balanceOf(address(alice)), 0);
        popPrank();
    }

    /**
     * @dev Test the contract's token balance remains correct after deposits and claims.
     */
    function testInvariantTokenBalance() public {
        uint256 initialContractBalance = spell.balanceOf(address(oSpellBank));
        _mintOSpell(1000 ether, alice);

        pushPrank(alice);
        oSpellBank.deposit(1000 ether, block.timestamp);
        popPrank();

        advanceTime(oSpellBank.nextUnlockTime());

        pushPrank(alice);
        oSpellBank.claim();
        popPrank();

        uint256 finalContractBalance = spell.balanceOf(address(oSpellBank));
        assertEq(finalContractBalance, initialContractBalance);
    }

    /**
     * @dev Ensure the total count of locks for a user is correct after deposits and claims.
     */
    function testInvariantTotalLocksCount() public {
        _mintOSpell(3000 ether, alice);

        pushPrank(alice);
        oSpellBank.deposit(1000 ether, block.timestamp);
        advanceTime(oSpellBank.EPOCH_DURATION());
        oSpellBank.deposit(1000 ether, block.timestamp);
        advanceTime(oSpellBank.EPOCH_DURATION());
        oSpellBank.deposit(1000 ether, block.timestamp);
        popPrank();

        uint256 lockCount = oSpellBank.userLocks(alice).length;
        assertEq(lockCount, 3);

        advanceTime(oSpellBank.nextUnlockTime());
        pushPrank(alice);
        oSpellBank.claim();
        popPrank();

        lockCount = oSpellBank.userLocks(alice).length;
        assertEq(lockCount, 0);

        assertEq(spell.balanceOf(address(alice)), 3000 ether);
        assertEq(oSpell.balanceOf(address(alice)), 0);
    }

    /**
     * @dev Test that claim returns 0 if there are no unlockable tokens.
     */
    function testReleaseLocksWithNoLocks() public {
        uint256 claimable = oSpellBank.claim();
        assertEq(claimable, 0);
    }

    /**
     * @dev Test claim with a single lock that is not yet unlockable.
     */
    function testReleaseLocksWithSingleLockedBalance() public {
        _mintOSpell(1000 ether, alice);

        pushPrank(alice);
        oSpellBank.deposit(1000 ether, block.timestamp + oSpellBank.EPOCH_DURATION());
        popPrank();

        uint256 claimable = oSpellBank.claim();
        assertEq(claimable, 0);
    }

    function _mintOSpell(uint256 amount, address to) internal {
        address owner = oSpellBank.owner();
        deal(spell, owner, amount);
        assertGe(spell.balanceOf(address(owner)), 1000 ether);

        pushPrank(owner);
        spell.safeApprove(address(oSpellBank), amount);
        oSpellBank.mint(amount, to);
        popPrank();
    }
}
