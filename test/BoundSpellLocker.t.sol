// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {BaseTest, ChainId} from "utils/BaseTest.sol";
import {LibSort} from "@solady/utils/LibSort.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {BoundSpellLockerScript} from "script/BoundSpellLocker.s.sol";
import {TokenLocker} from "/periphery/TokenLocker.sol";

import "forge-std/console2.sol";

contract TokenLockerTest is BaseTest {
    using SafeTransferLib for address;

    event LogDeposit(address indexed user, uint256 amount, uint256 unlockTime, uint256 lockCount);
    event LogClaimed(address indexed user, uint256 amount);
    event LogRedeem(address indexed user, uint256 amount, uint256 lockingDeadline);
    event LogInstantRedeem(address indexed user, uint256 immediateAmount, uint256 burnAmount, uint256 stakingAmount);
    event LogInstantRedeemParamsUpdated(address indexed user, uint256 immediateAmount, uint256 burnAmount, uint256 stakingAmount);
    event LogRescued(uint256 amount, address to);

    TokenLocker bSpellLocker;
    address spell;
    address bSpell;

    address[] users;

    function setUp() public override {
        fork(ChainId.Arbitrum, 249873942);
        super.setUp();

        BoundSpellLockerScript script = new BoundSpellLockerScript();
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
        bSpellLocker.redeem(0, block.timestamp);
    }

    function testMint() public {
        _mintbSpell(1000 ether, alice);
        assertEq(bSpell.balanceOf(address(alice)), 1000 ether);
    }

    function testDeposit() public {
        _mintbSpell(1000 ether, alice);

        pushPrank(alice);
        bSpellLocker.redeem(1000 ether, block.timestamp);
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
        bSpellLocker.redeem(1000 ether, block.timestamp + 100);
        assertEq(bSpell.balanceOf(address(alice)), 1000 ether);

        vm.expectEmit(true, true, true, true);
        emit LogDeposit(alice, 1000 ether, bSpellLocker.nextUnlockTime(), 1);
        bSpellLocker.redeem(1000 ether, block.timestamp + 200);
        assertEq(bSpell.balanceOf(address(alice)), 0);

        TokenLocker.LockedBalance[] memory locks = bSpellLocker.userLocks(alice);
        assertEq(locks.length, 1);
        assertEq(locks[0].amount, 2000 ether);
        assertEq(locks[0].unlockTime, bSpellLocker.nextUnlockTime());

        vm.warp(bSpellLocker.nextUnlockTime() + 1);

        vm.expectEmit(true, true, true, true);
        emit LogClaimed(alice, 2000 ether);
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
            bSpellLocker.redeem(1000 ether, block.timestamp);
            advanceTime(bSpellLocker.EPOCH_DURATION());
        }

        assertEq(bSpellLocker.userLocksLength(alice), bSpellLocker.maxLocks());
        vm.expectEmit(true, true, true, true);
        emit LogRedeem(alice, 1000 ether, block.timestamp);
        bSpellLocker.redeem(1000 ether, block.timestamp);
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
        bSpellLocker.redeem(1000 ether, block.timestamp - 1);
        popPrank();
    }

    function testPauseAndUnpause() public {
        address owner = bSpellLocker.owner();

        pushPrank(owner);
        bSpellLocker.pause();
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        bSpellLocker.redeem(1000 ether, block.timestamp + 100);

        bSpellLocker.unpause();
        _mintbSpell(1000 ether, alice);
        popPrank();

        pushPrank(alice);
        vm.expectEmit(true, true, true, true);
        emit LogDeposit(alice, 1000 ether, bSpellLocker.nextUnlockTime(), 1);
        bSpellLocker.redeem(1000 ether, block.timestamp + 100);
        assertEq(bSpell.balanceOf(address(alice)), 0);
        popPrank();
    }

    /**
     * @dev Test that a claim returns 0 if there are no unlockable tokens.
     */
    function testClaimingWithNoUnlocks() public {
        _mintbSpell(1000 ether, alice);

        pushPrank(alice);
        bSpellLocker.redeem(1000 ether, block.timestamp + 100);
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
        bSpellLocker.redeem(1000 ether, block.timestamp);
        uint256 firstLockExpiredAt = bSpellLocker.nextUnlockTime();
        advanceTime(bSpellLocker.EPOCH_DURATION());
        bSpellLocker.redeem(1000 ether, block.timestamp);
        uint256 secondLockExpiredAt = bSpellLocker.nextUnlockTime();
        TokenLocker.LockedBalance[] memory locks = bSpellLocker.userLocks(alice);
        assertEq(locks.length, 2);

        vm.warp(firstLockExpiredAt);
        vm.expectEmit(true, true, true, true);
        emit LogClaimed(alice, 1000 ether);
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
        emit LogClaimed(alice, 1000 ether);
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
        bSpellLocker.redeem(1000 ether, block.timestamp);
        advanceTime(bSpellLocker.EPOCH_DURATION());
        bSpellLocker.redeem(1000 ether, block.timestamp);
        advanceTime(bSpellLocker.EPOCH_DURATION());
        bSpellLocker.redeem(1000 ether, block.timestamp);

        TokenLocker.LockedBalance[] memory locks = bSpellLocker.userLocks(alice);
        assertEq(locks.length, 3);

        vm.warp(locks[0].unlockTime);
        vm.expectEmit(true, true, true, true);
        emit LogClaimed(alice, 1000 ether);
        uint256 claimable = bSpellLocker.claim();
        assertEq(claimable, 1000 ether);
        assertEq(spell.balanceOf(address(alice)), 1000 ether);

        locks = bSpellLocker.userLocks(alice);
        assertEq(locks.length, 2);
        vm.warp(locks[1].unlockTime);

        vm.expectEmit(true, true, true, true);
        emit LogClaimed(alice, 1000 ether);
        claimable = bSpellLocker.claim();
        assertEq(claimable, 1000 ether);
        assertEq(spell.balanceOf(address(alice)), 2000 ether);

        locks = bSpellLocker.userLocks(alice);
        assertEq(locks.length, 1);
        vm.warp(locks[0].unlockTime);

        vm.expectEmit(true, true, true, true);
        emit LogClaimed(alice, 1000 ether);
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
        bSpellLocker.redeem(2000 ether, block.timestamp);
        popPrank();

        pushPrank(bob);
        bSpellLocker.redeem(1000 ether, block.timestamp);
        popPrank();

        advanceTime(bSpellLocker.nextUnlockTime());

        pushPrank(bob);
        vm.expectEmit(true, true, true, true);
        emit LogClaimed(bob, 1000 ether);
        uint256 claimable = bSpellLocker.claim();
        assertEq(claimable, 1000 ether);
        assertEq(spell.balanceOf(address(bob)), 1000 ether);
        assertEq(bSpell.balanceOf(address(bob)), 0);
        popPrank();

        pushPrank(alice);
        vm.expectEmit(true, true, true, true);
        emit LogClaimed(alice, 2000 ether);
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
        bSpellLocker.redeem(1000 ether, block.timestamp);
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
        bSpellLocker.redeem(1000 ether, block.timestamp);
        advanceTime(bSpellLocker.EPOCH_DURATION());
        bSpellLocker.redeem(1000 ether, block.timestamp);
        advanceTime(bSpellLocker.EPOCH_DURATION());
        bSpellLocker.redeem(1000 ether, block.timestamp);
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
        bSpellLocker.redeem(1000 ether, block.timestamp + bSpellLocker.EPOCH_DURATION());
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
                    bSpellLocker.redeem(amount, block.timestamp);

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
        address stakingContract = makeAddr("stakingContract");
        TokenLocker.InstantRedeemParams memory params = TokenLocker.InstantRedeemParams({
            immediateBips: 5000, // 50%
            burnBips: 3000, // 30%
            stakingContract: stakingContract
        });

        address owner = bSpellLocker.owner();
        pushPrank(owner);
        bSpellLocker.updateInstantRedeemParams(params);
        popPrank();

        uint256 amount = 1000 ether;
        _mintbSpell(amount, alice);

        uint256 expectedImmediate = (amount * params.immediateBips) / bSpellLocker.BIPS();
        uint256 expectedBurn = (amount * params.burnBips) / bSpellLocker.BIPS();
        uint256 expectedStaking = amount - expectedImmediate - expectedBurn;

        pushPrank(alice);
        vm.expectEmit(true, true, true, true);
        emit LogInstantRedeem(alice, expectedImmediate, expectedBurn, expectedStaking);
        bSpellLocker.instantRedeem(amount);

        assertEq(bSpell.balanceOf(address(alice)), 0);
        assertEq(spell.balanceOf(address(alice)), expectedImmediate);
        assertEq(spell.balanceOf(bSpellLocker.BURN_ADDRESS()), expectedBurn);
        assertEq(bSpell.balanceOf(stakingContract), expectedStaking);
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
        bSpellLocker.redeem(1000 ether, block.timestamp);
        popPrank();

        assertEq(bSpell.balanceOf(address(alice)), 0);
        assertEq(spell.balanceOf(address(alice)), 0);

        TokenLocker.LockedBalance[] memory locks = bSpellLocker.userLocks(alice);
        assertEq(locks.length, 1);
        assertEq(locks[0].amount, 1000 ether);
        assertEq(locks[0].unlockTime, bSpellLocker.nextUnlockTime());

        vm.expectRevert(abi.encodeWithSignature("ErrFoo(string)", "foo"));
        bSpellLocker.instantRedeem(1000 ether);
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

    function instantRedeem(uint256) public view override returns (uint256) {
        revert ErrFoo(foo);
    }
}
