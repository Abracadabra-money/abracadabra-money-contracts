// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {BaseTest, ChainId} from "utils/BaseTest.sol";
import {LibSort} from "@solady/utils/LibSort.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {BoundSpellScript} from "script/BoundSpell.s.sol";
import {TokenLocker} from "/periphery/TokenLocker.sol";
import {OwnableOperators} from "/mixins/OwnableOperators.sol";

import "forge-std/console2.sol";

contract BoundSpellTest is BaseTest {
    using SafeTransferLib for address;

    event LogDeposit(address indexed user, uint256 amount, uint256 unlockTime, uint256 lockCount);
    event LogClaimed(address indexed user, address indexed to, uint256 amount);
    event LogRedeem(address indexed from, address indexed to, uint256 amount, uint256 lockingDeadline);
    event LogInstantRedeem(address indexed from, address indexed to, uint256 immediateAmount, uint256 burnAmount, uint256 stakingAmount);
    event LogInstantRedeemParamsUpdated(address indexed user, uint256 immediateAmount, uint256 burnAmount, uint256 stakingAmount);
    event LogRescued(uint256 amount, address to);

    TokenLocker bSpellLocker;
    address spell;
    address bSpell;

    address[] users;

    function setUp() public override {
        fork(ChainId.Arbitrum, 287794543);
        super.setUp();

        BoundSpellScript script = new BoundSpellScript();
        script.setTesting(true);

        (bSpellLocker) = script.deploy();

        spell = bSpellLocker.underlyingToken();
        bSpell = bSpellLocker.asset();

        assertEq(bSpellLocker.maxLocks(), 14);

        users.push(createUser("user1", makeAddr("user1"), 0));
        users.push(createUser("user2", makeAddr("user2"), 0));
        users.push(createUser("user3", makeAddr("user3"), 0));
        users.push(createUser("user4", makeAddr("user4"), 0));
        users.push(createUser("user5", makeAddr("user5"), 0));
        users.push(createUser("user6", makeAddr("user6"), 0));
    }

    function testDepositZeroAmount() public {
        vm.expectRevert(TokenLocker.ErrZeroAmount.selector);
        bSpellLocker.redeem(0, address(this), block.timestamp);
    }

    function testMint() public {
        _mintbSpell(1000 ether, alice);
        assertEq(bSpell.balanceOf(address(alice)), 1000 ether);
    }

    function testDeposit() public {
        _mintbSpell(1000 ether, alice);

        pushPrank(alice);
        bSpellLocker.redeem(1000 ether, alice, block.timestamp);
        assertEq(bSpell.balanceOf(address(alice)), 0);
        assertEq(spell.balanceOf(address(alice)), 0);

        // checks lock
        TokenLocker.LockedBalance[] memory locks = bSpellLocker.userLocks(alice);
        assertEq(locks.length, 1);
        assertEq(locks[0].amount, 1000 ether);
        assertEq(locks[0].unlockTime, bSpellLocker.nextUnlockTime());

        vm.warp(bSpellLocker.nextUnlockTime() + 1);
        bSpellLocker.claim();
        assertEq(spell.balanceOf(address(alice)), 1000 ether);
        assertEq(bSpell.balanceOf(address(alice)), 0);

        locks = bSpellLocker.userLocks(alice);
        assertEq(locks.length, 0);
        popPrank();
    }

    function testDepositAndClaimSingleLock() public {
        _mintbSpell(2000 ether, alice);

        pushPrank(alice);
        vm.expectEmit(true, true, true, true);
        emit LogDeposit(alice, 1000 ether, bSpellLocker.nextUnlockTime(), 1);
        bSpellLocker.redeem(1000 ether, alice, block.timestamp + 100);
        assertEq(bSpell.balanceOf(address(alice)), 1000 ether);

        vm.expectEmit(true, true, true, true);
        emit LogDeposit(alice, 1000 ether, bSpellLocker.nextUnlockTime(), 1);
        bSpellLocker.redeem(1000 ether, alice, block.timestamp + 200);
        assertEq(bSpell.balanceOf(address(alice)), 0);

        TokenLocker.LockedBalance[] memory locks = bSpellLocker.userLocks(alice);
        assertEq(locks.length, 1);
        assertEq(locks[0].amount, 2000 ether);
        assertEq(locks[0].unlockTime, bSpellLocker.nextUnlockTime());

        vm.warp(bSpellLocker.nextUnlockTime() + 1);

        vm.expectEmit(true, true, true, true);
        emit LogClaimed(alice, alice, 2000 ether);
        bSpellLocker.claim();
        assertEq(spell.balanceOf(address(alice)), 2000 ether);
        assertEq(bSpell.balanceOf(address(alice)), 0);

        locks = bSpellLocker.userLocks(alice);
        assertEq(locks.length, 0);
        popPrank();
    }

    function testMaxUserLocksExceeded() public {
        _mintbSpell(100_000 ether, alice);

        pushPrank(alice);

        vm.warp(0); // reset time
        for (uint256 i = 0; i < bSpellLocker.maxLocks(); i++) {
            vm.expectEmit(true, true, true, true);
            emit LogDeposit(alice, 1000 ether, bSpellLocker.nextUnlockTime(), i + 1);
            bSpellLocker.redeem(1000 ether, alice, block.timestamp);
            advanceTime(bSpellLocker.EPOCH_DURATION());
        }

        assertEq(bSpellLocker.userLocksLength(alice), bSpellLocker.maxLocks());
        vm.expectEmit(true, true, true, true);
        emit LogRedeem(alice, alice, 1000 ether, block.timestamp);
        bSpellLocker.redeem(1000 ether, alice, block.timestamp);
        assertEq(bSpellLocker.userLocksLength(alice), bSpellLocker.maxLocks());

        popPrank();
    }

    function testInvalidLockDuration() public {
        address owner = bSpellLocker.owner();

        pushPrank(owner);
        vm.expectRevert(TokenLocker.ErrInvalidLockDuration.selector);
        new TokenLocker(address(bSpell), address(spell), 1 days);

        vm.expectRevert(TokenLocker.ErrInvalidDurationRatio.selector);
        new TokenLocker(address(bSpell), address(spell), 8 days);
        popPrank();
    }

    function testExpiredLockingDeadline() public {
        _mintbSpell(1000 ether, alice);

        pushPrank(alice);
        vm.expectRevert(TokenLocker.ErrExpired.selector);
        bSpellLocker.redeem(1000 ether, alice, block.timestamp - 1);
        popPrank();
    }

    function testPauseAndUnpause() public {
        address owner = bSpellLocker.owner();

        pushPrank(owner);
        bSpellLocker.pause();
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        bSpellLocker.redeem(1000 ether, owner, block.timestamp + 100);

        bSpellLocker.unpause();
        _mintbSpell(1000 ether, alice);
        popPrank();

        pushPrank(alice);
        vm.expectEmit(true, true, true, true);
        emit LogDeposit(alice, 1000 ether, bSpellLocker.nextUnlockTime(), 1);
        bSpellLocker.redeem(1000 ether, alice, block.timestamp + 100);
        assertEq(bSpell.balanceOf(address(alice)), 0);
        popPrank();
    }

    /**
     * @dev Test that a claim returns 0 if there are no unlockable tokens.
     */
    function testClaimingWithNoUnlocks() public {
        _mintbSpell(1000 ether, alice);

        pushPrank(alice);
        bSpellLocker.redeem(1000 ether, alice, block.timestamp + 100);
        uint256 claimable = bSpellLocker.claim();
        assertEq(claimable, 0);
        popPrank();
    }

    /**
     * @dev Test partial claims when only some of the deposited tokens are unlocked.
     */
    function testClaimPartialUnlock() public {
        _mintbSpell(2000 ether, alice);

        pushPrank(alice);
        bSpellLocker.redeem(1000 ether, alice, block.timestamp);
        uint256 firstLockExpiredAt = bSpellLocker.nextUnlockTime();
        advanceTime(bSpellLocker.EPOCH_DURATION());
        bSpellLocker.redeem(1000 ether, alice, block.timestamp);
        uint256 secondLockExpiredAt = bSpellLocker.nextUnlockTime();
        TokenLocker.LockedBalance[] memory locks = bSpellLocker.userLocks(alice);
        assertEq(locks.length, 2);

        vm.warp(firstLockExpiredAt);
        vm.expectEmit(true, true, true, true);
        emit LogClaimed(alice, alice, 1000 ether);
        uint256 claimable = bSpellLocker.claim();
        assertEq(claimable, 1000 ether);
        assertEq(spell.balanceOf(address(alice)), 1000 ether);
        assertEq(bSpell.balanceOf(address(alice)), 0);

        locks = bSpellLocker.userLocks(alice);
        assertEq(locks.length, 1);
        assertEq(locks[0].amount, 1000 ether);
        assertEq(locks[0].unlockTime, secondLockExpiredAt);

        vm.warp(secondLockExpiredAt + 1);

        vm.expectEmit(true, true, true, true);
        emit LogClaimed(alice, alice, 1000 ether);
        claimable = bSpellLocker.claim();
        assertEq(claimable, 1000 ether);
        assertEq(spell.balanceOf(address(alice)), 2000 ether);
        assertEq(bSpell.balanceOf(address(alice)), 0);

        locks = bSpellLocker.userLocks(alice);
        assertEq(locks.length, 0);
        popPrank();
    }

    /**
     * @dev Test claims with multiple deposits and staggered unlock times.
     */
    function testClaimWithMultipleDepositsAndUnlocks() public {
        _mintbSpell(3000 ether, alice);

        pushPrank(alice);
        bSpellLocker.redeem(1000 ether, alice, block.timestamp);
        advanceTime(bSpellLocker.EPOCH_DURATION());
        bSpellLocker.redeem(1000 ether, alice, block.timestamp);
        advanceTime(bSpellLocker.EPOCH_DURATION());
        bSpellLocker.redeem(1000 ether, alice, block.timestamp);

        TokenLocker.LockedBalance[] memory locks = bSpellLocker.userLocks(alice);
        assertEq(locks.length, 3);

        vm.warp(locks[0].unlockTime);
        vm.expectEmit(true, true, true, true);
        emit LogClaimed(alice, alice, 1000 ether);
        uint256 claimable = bSpellLocker.claim();
        assertEq(claimable, 1000 ether);
        assertEq(spell.balanceOf(address(alice)), 1000 ether);

        locks = bSpellLocker.userLocks(alice);
        assertEq(locks.length, 2);
        vm.warp(locks[1].unlockTime);

        vm.expectEmit(true, true, true, true);
        emit LogClaimed(alice, alice, 1000 ether);
        claimable = bSpellLocker.claim();
        assertEq(claimable, 1000 ether);
        assertEq(spell.balanceOf(address(alice)), 2000 ether);

        locks = bSpellLocker.userLocks(alice);
        assertEq(locks.length, 1);
        vm.warp(locks[0].unlockTime);

        vm.expectEmit(true, true, true, true);
        emit LogClaimed(alice, alice, 1000 ether);
        claimable = bSpellLocker.claim();
        assertEq(claimable, 1000 ether);
        assertEq(spell.balanceOf(address(alice)), 3000 ether);
        assertEq(bSpell.balanceOf(address(alice)), 0);

        locks = bSpellLocker.userLocks(alice);
        assertEq(locks.length, 0);
        popPrank();
    }

    /**
     * @dev Ensure claims by one user do not affect another user's locked tokens.
     */
    function testClaimingDoesNotAffectOtherUsers() public {
        _mintbSpell(2000 ether, alice);
        _mintbSpell(1000 ether, bob);

        pushPrank(alice);
        bSpellLocker.redeem(2000 ether, alice, block.timestamp);
        popPrank();

        pushPrank(bob);
        bSpellLocker.redeem(1000 ether, bob, block.timestamp);
        popPrank();

        advanceTime(bSpellLocker.nextUnlockTime());

        pushPrank(bob);
        vm.expectEmit(true, true, true, true);
        emit LogClaimed(bob, bob, 1000 ether);
        uint256 claimable = bSpellLocker.claim();
        assertEq(claimable, 1000 ether);
        assertEq(spell.balanceOf(address(bob)), 1000 ether);
        assertEq(bSpell.balanceOf(address(bob)), 0);
        popPrank();

        pushPrank(alice);
        vm.expectEmit(true, true, true, true);
        emit LogClaimed(alice, alice, 2000 ether);
        claimable = bSpellLocker.claim();
        assertEq(claimable, 2000 ether);
        assertEq(spell.balanceOf(address(alice)), 2000 ether);
        assertEq(bSpell.balanceOf(address(alice)), 0);
        popPrank();
    }

    /**
     * @dev Test the contract's token balance remains correct after deposits and claims.
     */
    function testInvariantTokenBalance() public {
        uint256 initialContractBalance = spell.balanceOf(address(bSpellLocker));
        _mintbSpell(1000 ether, alice);

        pushPrank(alice);
        bSpellLocker.redeem(1000 ether, alice, block.timestamp);
        popPrank();

        advanceTime(bSpellLocker.nextUnlockTime());

        pushPrank(alice);
        bSpellLocker.claim();
        popPrank();

        uint256 finalContractBalance = spell.balanceOf(address(bSpellLocker));
        assertEq(finalContractBalance, initialContractBalance);
    }

    /**
     * @dev Ensure the total count of locks for a user is correct after deposits and claims.
     */
    function testInvariantTotalLocksCount() public {
        _mintbSpell(3000 ether, alice);

        pushPrank(alice);
        bSpellLocker.redeem(1000 ether, alice, block.timestamp);
        advanceTime(bSpellLocker.EPOCH_DURATION());
        bSpellLocker.redeem(1000 ether, alice, block.timestamp);
        advanceTime(bSpellLocker.EPOCH_DURATION());
        bSpellLocker.redeem(1000 ether, alice, block.timestamp);
        popPrank();

        uint256 lockCount = bSpellLocker.userLocks(alice).length;
        assertEq(lockCount, 3);

        advanceTime(bSpellLocker.nextUnlockTime());
        pushPrank(alice);
        bSpellLocker.claim();
        popPrank();

        lockCount = bSpellLocker.userLocks(alice).length;
        assertEq(lockCount, 0);

        assertEq(spell.balanceOf(address(alice)), 3000 ether);
        assertEq(bSpell.balanceOf(address(alice)), 0);
    }

    /**
     * @dev Test that claim returns 0 if there are no unlockable tokens.
     */
    function testReleaseLocksWithNoLocks() public {
        uint256 claimable = bSpellLocker.claim();
        assertEq(claimable, 0);
    }

    /**
     * @dev Test claim with a single lock that is not yet unlockable.
     */
    function testReleaseLocksWithSingleLockedBalance() public {
        _mintbSpell(1000 ether, alice);

        pushPrank(alice);
        bSpellLocker.redeem(1000 ether, alice, block.timestamp + bSpellLocker.EPOCH_DURATION());
        popPrank();

        uint256 claimable = bSpellLocker.claim();
        assertEq(claimable, 0);
    }

    function testSpammingDeposits(uint256 iterations) public onlyProfile("ci") {
        iterations = 4;

        iterations = bound(iterations, 100, 200);
        for (uint256 i = 0; i < iterations; i++) {
            for (uint256 j = 0; j < users.length; j++) {
                address user = users[j];
                console2.log("user", user);
                // 1 chance in 5 to deposit
                uint256 rngDeposit = vm.randomUint(1, 5);
                if (rngDeposit == 1) {
                    uint256 amount = vm.randomUint(1, 100_000 ether);

                    TokenLocker.LockedBalance[] memory locksBefore = bSpellLocker.userLocks(user);
                    uint256 latestUnlockTime = 0;
                    uint256 latestLockAmount = 0;

                    for (uint256 k = 0; k < locksBefore.length; k++) {
                        assertNotEq(locksBefore[k].unlockTime, latestUnlockTime);

                        if (locksBefore[k].unlockTime > latestUnlockTime) {
                            latestUnlockTime = locksBefore[k].unlockTime;
                            latestLockAmount = locksBefore[k].amount;
                        }
                    }

                    console2.log("latestUnlockTime", latestUnlockTime);
                    console2.log("latestLockAmount", latestLockAmount);
                    console2.log("locksBefore", locksBefore.length);
                    _printLocks(user);
                    _mintbSpell(amount, user);
                    vm.prank(user);
                    bSpellLocker.redeem(amount, user, block.timestamp);

                    _checkLastLockIndexIsNewestLock(user);

                    TokenLocker.LockedBalance[] memory locksAfter = bSpellLocker.userLocks(user);

                    console2.log("locksAfter", locksAfter.length);

                    // added to the same lock
                    uint256 newUnlockTime = 0;
                    for (uint256 k = 0; k < locksAfter.length; k++) {
                        assertTrue(newUnlockTime == 0 || newUnlockTime > locksAfter[k].unlockTime, "2 new locks created");

                        if (locksAfter[k].unlockTime > latestUnlockTime) {
                            newUnlockTime = locksAfter[k].unlockTime;
                            assertEq(locksAfter[k].amount, amount);
                        }
                    }

                    // crated a new lock
                    if (newUnlockTime == 0) {
                        assertEq(latestLockAmount + amount, locksAfter[bSpellLocker.lastLockIndex(user)].amount);
                    }
                }
            }

            advanceTime(vm.randomUint(1 minutes, 1 weeks));
        }
    }

    function testInstantRedeem() public {
        address feeCollector = makeAddr("feeCollector");
        TokenLocker.InstantRedeemParams memory params = TokenLocker.InstantRedeemParams({
            immediateBips: 5000, // 50%
            burnBips: 3000, // 30%
            feeCollector: feeCollector
        });

        address owner = bSpellLocker.owner();
        pushPrank(owner);
        bSpellLocker.updateInstantRedeemParams(params);
        popPrank();

        uint256 amount = 1000 ether;
        _mintbSpell(amount, alice);

        uint256 expectedImmediate = (amount * params.immediateBips) / bSpellLocker.BIPS();
        uint256 expectedBurn = (amount * params.burnBips) / bSpellLocker.BIPS();
        uint256 expectedFeeCollector = amount - expectedImmediate - expectedBurn;

        uint256 previousBurnBalance = spell.balanceOf(bSpellLocker.BURN_ADDRESS());
        pushPrank(alice);
        vm.expectEmit(true, true, true, true);
        emit LogInstantRedeem(alice, alice, expectedImmediate, expectedBurn, expectedFeeCollector);
        bSpellLocker.instantRedeem(amount, alice);

        assertEq(bSpell.balanceOf(address(alice)), 0);
        assertEq(spell.balanceOf(address(alice)), expectedImmediate);
        assertEq(spell.balanceOf(bSpellLocker.BURN_ADDRESS()), previousBurnBalance + expectedBurn);
        assertEq(bSpell.balanceOf(feeCollector), expectedFeeCollector);
        popPrank();
    }

    function testUpgrade() public {
        address owner = bSpellLocker.owner();

        // Deploy the new implementation
        TokenLockerV2 lockerV2 = new TokenLockerV2(address(bSpell), address(spell), 13 weeks);

        // Upgrade the locker
        pushPrank(owner);
        bSpellLocker.upgradeToAndCall(address(lockerV2), abi.encodeCall(TokenLockerV2.initialize, ("foo")));
        popPrank();

        // Verify state is preserved
        assertEq(bSpellLocker.asset(), bSpell);
        assertEq(bSpellLocker.underlyingToken(), spell);
        assertEq(bSpellLocker.lockDuration(), 13 weeks);
        assertEq(bSpellLocker.maxLocks(), 14);

        // Interact with the new implementation
        _mintbSpell(1000 ether, alice);

        pushPrank(alice);
        bSpellLocker.redeem(1000 ether, alice, block.timestamp);
        popPrank();

        assertEq(bSpell.balanceOf(address(alice)), 0);
        assertEq(spell.balanceOf(address(alice)), 0);

        TokenLocker.LockedBalance[] memory locks = bSpellLocker.userLocks(alice);
        assertEq(locks.length, 1);
        assertEq(locks[0].amount, 1000 ether);
        assertEq(locks[0].unlockTime, bSpellLocker.nextUnlockTime());

        vm.expectRevert(abi.encodeWithSignature("ErrFoo(string)", "foo"));
        bSpellLocker.instantRedeem(1000 ether, msg.sender);
    }

    function testRedeemToAddress() public {
        _mintbSpell(1000 ether, alice);

        uint256 currentSupply = IERC20Metadata(bSpell).totalSupply();
        assertEq(currentSupply, 1000 ether, "bSpell total supply should have increased");
        pushPrank(alice);
        bSpellLocker.redeem(1000 ether, bob, block.timestamp);
        popPrank();
        assertEq(IERC20Metadata(bSpell).totalSupply(), 0, "bSpell total supply should have decreased");

        // Check that bSpell tokens were transferred from Alice to the locker
        assertEq(bSpell.balanceOf(address(alice)), 0, "Alice has incorrect bSpell balance");
        assertEq(bSpell.balanceOf(address(bSpellLocker)), 0, "Locker should not hold any bSpell");

        // Check that Bob has the correct locks
        TokenLocker.LockedBalance[] memory bobLocks = bSpellLocker.userLocks(bob);
        assertEq(bobLocks.length, 1, "Bob has incorrect number of locks");
        assertEq(bobLocks[0].amount, 1000 ether, "Bob has incorrect lock amount");
        assertEq(bobLocks[0].unlockTime, bSpellLocker.nextUnlockTime(), "Bob has incorrect unlock time");

        // Verify Bob's lock count
        assertEq(bSpellLocker.userLocksLength(bob), 1, "Bob has incorrect lock count");

        // Ensure Alice has no locks
        TokenLocker.LockedBalance[] memory aliceLocks = bSpellLocker.userLocks(alice);
        assertEq(aliceLocks.length, 0, "Alice has incorrect number of locks");
        assertEq(bSpellLocker.userLocksLength(alice), 0, "Alice has incorrect lock count");

        advanceTime(bSpellLocker.nextUnlockTime());

        pushPrank(bob);
        vm.expectEmit(true, true, true, true);
        emit LogClaimed(bob, bob, 1000 ether);
        uint256 claimable = bSpellLocker.claim();
        assertEq(claimable, 1000 ether);
        assertEq(spell.balanceOf(address(bob)), 1000 ether);
        assertEq(bSpell.balanceOf(address(bob)), 0);
        popPrank();
    }

    function testInstantRedeemToAddress() public {
        // Set up instant redeem parameters
        address feeCollector = makeAddr("feeCollector");
        TokenLocker.InstantRedeemParams memory params = TokenLocker.InstantRedeemParams({
            immediateBips: 5000, // 50%
            burnBips: 3000, // 30%
            feeCollector: feeCollector
        });

        address owner = bSpellLocker.owner();
        pushPrank(owner);
        bSpellLocker.updateInstantRedeemParams(params);
        popPrank();

        uint256 amount = 1000 ether;
        _mintbSpell(amount, alice);

        uint256 currentSupply = IERC20Metadata(bSpell).totalSupply();
        assertEq(currentSupply, amount, "bSpell total supply should have increased");

        uint256 previousBurnBalance = spell.balanceOf(bSpellLocker.BURN_ADDRESS());

        pushPrank(alice);
        vm.expectEmit(true, true, true, true);
        emit LogInstantRedeem(alice, bob, 500 ether, 300 ether, 200 ether);
        uint256 claimable = bSpellLocker.instantRedeem(amount, bob);
        popPrank();

        assertEq(IERC20Metadata(bSpell).totalSupply(), 200 ether, "bSpell total supply should have decreased by burned amount");

        // Check that bSpell tokens were transferred from Alice
        assertEq(bSpell.balanceOf(address(alice)), 0, "Alice has incorrect bSpell balance");
        assertEq(bSpell.balanceOf(address(bSpellLocker)), 0, "Locker should not hold any bSpell");

        // Check that Bob received the immediate amount
        assertEq(spell.balanceOf(address(bob)), 500 ether, "Bob has incorrect SPELL balance");

        // Check that the burn address received the burn amount
        assertEq(spell.balanceOf(bSpellLocker.BURN_ADDRESS()), previousBurnBalance + 300 ether, "Burn address has incorrect SPELL balance");

        // Check that the fee collector received the fee amount
        assertEq(bSpell.balanceOf(feeCollector), 200 ether, "FeeCollector has incorrect bSPELL balance");

        // Ensure Alice and Bob have no locks
        assertEq(bSpellLocker.userLocksLength(alice), 0, "Alice has incorrect lock count");
        assertEq(bSpellLocker.userLocksLength(bob), 0, "Bob has incorrect lock count");

        // Check claimable amount (should be 0 as instant redeem doesn't create locks)
        assertEq(claimable, 0, "Claimable amount should be 0");
    }

    function testFuzzRedeemDifferentFromAndTo(address from, address to, uint256 amount) public {
        vm.assume(from != to);
        vm.assume(from != address(0));
        vm.assume(to != address(0));
        vm.assume(amount > 0 && amount <= 1_000_000 ether);

        _mintbSpell(amount, from);

        pushPrank(from);
        vm.expectEmit(true, true, true, true);
        emit LogRedeem(from, to, amount, block.timestamp);
        bSpellLocker.redeem(amount, to, block.timestamp);
        popPrank();

        assertEq(bSpell.balanceOf(from), 0, "From address should have no bSpell balance");

        TokenLocker.LockedBalance[] memory locks = bSpellLocker.userLocks(to);
        assertEq(locks.length, 1, "To address should have one lock");
        assertEq(locks[0].amount, amount, "Lock amount should match redeemed amount");
        assertEq(locks[0].unlockTime, bSpellLocker.nextUnlockTime(), "Unlock time should be next unlock time");

        _checkLastLockIndexIsNewestLock(to);

        vm.warp(bSpellLocker.nextUnlockTime() + 1);

        pushPrank(to);
        uint256 claimable = bSpellLocker.claim();
        popPrank();

        assertEq(claimable, amount, "Claimable amount should match redeemed amount");
        assertEq(spell.balanceOf(to), amount, "To address should receive SPELL tokens after claim");
    }

    function testRedeemToLockerAddressFails() public {
        uint256 amount = 1000 ether;
        _mintbSpell(amount, alice);

        vm.prank(alice);
        vm.expectRevert(TokenLocker.ErrInvalidAddress.selector);
        bSpellLocker.redeem(amount, address(bSpellLocker), block.timestamp);
    }

    function testInstantRedeemToLockerAddressFails() public {
        uint256 amount = 1000 ether;
        _mintbSpell(amount, alice);

        vm.prank(alice);
        vm.expectRevert(TokenLocker.ErrInvalidAddress.selector);
        bSpellLocker.instantRedeem(amount, address(bSpellLocker));
    }

    function testRedeemForAsOperator() public {
        address operator = makeAddr("operator");
        _addOperator(operator);

        _mintbSpell(1000 ether, alice);

        vm.prank(operator);
        vm.expectEmit(true, true, true, true);
        emit LogRedeem(alice, bob, 1000 ether, block.timestamp);
        uint256 amountClaimed = bSpellLocker.redeemFor(alice, 1000 ether, bob, block.timestamp);

        assertEq(amountClaimed, 0, "Incorrect amount claimed");
        assertEq(bSpell.balanceOf(alice), 0, "Alice should have no bSpell balance");

        TokenLocker.LockedBalance[] memory locks = bSpellLocker.userLocks(bob);
        assertEq(locks.length, 1, "Bob should have one lock");
        assertEq(locks[0].amount, 1000 ether, "Lock amount should match redeemed amount");
        assertEq(locks[0].unlockTime, bSpellLocker.nextUnlockTime(), "Unlock time should be next unlock time");
    }

    function testRedeemForAsNonOperatorFails() public {
        _mintbSpell(1000 ether, alice);

        vm.prank(bob);
        vm.expectRevert(OwnableOperators.Unauthorized.selector);
        bSpellLocker.redeemFor(alice, 1000 ether, bob, block.timestamp);
    }

    function testInstantRedeemForAsOperator() public {
        address operator = makeAddr("operator");
        _addOperator(operator);

        // Set up instant redeem parameters
        address feeCollector = makeAddr("feeCollector");
        TokenLocker.InstantRedeemParams memory params = TokenLocker.InstantRedeemParams({
            immediateBips: 5000, // 50%
            burnBips: 3000, // 30%
            feeCollector: feeCollector
        });

        address owner = bSpellLocker.owner();
        vm.prank(owner);
        bSpellLocker.updateInstantRedeemParams(params);

        uint256 amount = 1000 ether;
        _mintbSpell(amount, alice);

        uint256 previousBurnBalance = spell.balanceOf(bSpellLocker.BURN_ADDRESS());

        vm.prank(operator);
        vm.expectEmit(true, true, true, true);
        emit LogInstantRedeem(alice, bob, 500 ether, 300 ether, 200 ether);
        uint256 amountClaimed = bSpellLocker.instantRedeemFor(alice, amount, bob);

        assertEq(amountClaimed, 0, "Incorrect amount claimed");
        assertEq(bSpell.balanceOf(alice), 0, "Alice should have no bSpell balance");
        assertEq(spell.balanceOf(bob), 500 ether, "Bob should receive immediate amount");
        assertEq(spell.balanceOf(bSpellLocker.BURN_ADDRESS()), previousBurnBalance + 300 ether, "Burn amount should go to burn address");
        assertEq(bSpell.balanceOf(feeCollector), 200 ether, "fee amount should go to feeCollector");

        params.feeCollector = address(0);
        vm.prank(owner);
        bSpellLocker.updateInstantRedeemParams(params);
        _mintbSpell(amount, alice);

        vm.prank(alice);
        vm.expectRevert(TokenLocker.ErrNotEnabled.selector);
        bSpellLocker.instantRedeem(amount, alice);
    }

    function testInstantRedeemForAsNonOperatorFails() public {
        _mintbSpell(1000 ether, alice);

        vm.prank(bob);
        vm.expectRevert(OwnableOperators.Unauthorized.selector);
        bSpellLocker.instantRedeemFor(alice, 1000 ether, bob);
    }

    function testClaimForAsOperator() public {
        address operator = makeAddr("operator");
        _addOperator(operator);

        _mintbSpell(1000 ether, alice);
        vm.prank(alice);
        bSpellLocker.redeem(1000 ether, alice, block.timestamp);

        vm.warp(bSpellLocker.nextUnlockTime() + 1);

        vm.prank(operator);
        vm.expectEmit(true, true, true, true);
        emit LogClaimed(alice, bob, 1000 ether);
        uint256 amountClaimed = bSpellLocker.claimFor(alice, bob);

        assertEq(amountClaimed, 1000 ether, "Incorrect amount claimed");
        assertEq(spell.balanceOf(bob), 1000 ether, "Bob should receive claimed tokens");
    }

    function testClaimForAsNonOperatorFails() public {
        _mintbSpell(1000 ether, alice);
        vm.prank(alice);
        bSpellLocker.redeem(1000 ether, alice, block.timestamp);

        vm.warp(bSpellLocker.nextUnlockTime() + 1);

        vm.prank(bob);
        vm.expectRevert(OwnableOperators.Unauthorized.selector);
        bSpellLocker.claimFor(alice, bob);
    }

    function _addOperator(address operator) internal {
        address owner = bSpellLocker.owner();
        pushPrank(owner);
        bSpellLocker.setOperator(operator, true);
        popPrank();
    }

    function _checkLastLockIndexIsNewestLock(address user) internal view {
        TokenLocker.LockedBalance[] memory locks = bSpellLocker.userLocks(user);
        uint256 lastLockIndex = bSpellLocker.lastLockIndex(user);
        uint256 newestUnlockTime = 0;
        uint256 newestLockIndex = 0;

        for (uint256 i = 0; i < locks.length; i++) {
            if (locks[i].unlockTime > newestUnlockTime) {
                newestUnlockTime = locks[i].unlockTime;
                newestLockIndex = i;
            }
        }

        assertEq(lastLockIndex, newestLockIndex, "lastLockIndex is not the newest lock");
    }

    function _printLocks(address user) internal view {
        string memory header1;
        string memory row1;
        string memory row2;
        string memory row3;

        TokenLocker.LockedBalance[] memory locks = bSpellLocker.userLocks(user);
        uint256[] memory unlockTimes = new uint256[](locks.length);

        for (uint256 i = 0; i < locks.length; i++) {
            unlockTimes[i] = locks[i].unlockTime;
        }

        uint256 lastLockIndex = bSpellLocker.lastLockIndex(user);
        uint256 currentTime = block.timestamp;

        // sort ASC unlockTimes
        LibSort.sort(unlockTimes);
        assertTrue(LibSort.isSortedAndUniquified(unlockTimes), "not sorted");

        for (uint256 i = 0; i < locks.length; i++) {
            for (uint256 j = 0; j < unlockTimes.length; j++) {
                if (locks[i].unlockTime == unlockTimes[j]) {
                    header1 = string.concat(header1, vm.toString(i), "\t\t| ");
                    row1 = string.concat(row1, "r: ", vm.toString(j), "\t\t| ");
                    row2 = string.concat(row2, "t: ", vm.toString(locks[i].unlockTime), "\t| ");

                    if (i == lastLockIndex) {
                        row3 = string.concat(row3, unicode"   ↑   ", "\t\t");
                    } else {
                        row3 = string.concat(row3, "\t\t");
                    }
                    break;
                }
            }
        }

        console2.log(string.concat("==== ", vm.toString(user), " ===="));
        console2.log("lastLockIndex", lastLockIndex);
        console2.log("nextUnlockTime", bSpellLocker.nextUnlockTime());
        console2.log("currentTime", currentTime);
        console2.log(header1);
        console2.log(row1);
        console2.log(row2);
        console2.log(row3);
    }

    function _mintbSpell(uint256 amount, address to) internal {
        address owner = bSpellLocker.owner();
        uint256 balance = spell.balanceOf(owner);
        deal(spell, owner, amount);
        assertGe(spell.balanceOf(address(owner)), balance + amount);

        pushPrank(owner);
        spell.safeApprove(address(bSpellLocker), amount);

        uint supplyBefore = IERC20Metadata(bSpell).totalSupply();
        bSpellLocker.mint(amount, to);
        assertEq(IERC20Metadata(bSpell).totalSupply(), supplyBefore + amount, "supply didn't change?");
        popPrank();
    }
}

contract TokenLockerV2 is TokenLocker {
    error ErrFoo(string message);

    string foo;

    constructor(address _asset, address _underlyingToken, uint256 _lockDuration) TokenLocker(_asset, _underlyingToken, _lockDuration) {}

    function initialize(string memory _foo) public {
        foo = _foo;
    }

    function instantRedeem(uint256, address) public view override returns (uint256) {
        revert ErrFoo(foo);
    }
}
