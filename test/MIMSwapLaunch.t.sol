// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/MIMSwapLaunch.s.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {BlastOnboardingData, BlastOnboarding} from "/blast/BlastOnboarding.sol";
import {BlastOnboardingBoot} from "/blast/BlastOnboardingBoot.sol";
import {IMagicLP} from "/mimswap/interfaces/IMagicLP.sol";
import {DecimalMath} from "/mimswap/libraries/DecimalMath.sol";
import {LockingMultiRewards} from "staking/LockingMultiRewards.sol";

contract MIMSwapLaunchTest is BaseTest {
    using SafeTransferLib for address;
    event LogClaimed(address indexed user, uint256 shares, bool lock);

    BlastOnboarding constant onboarding = BlastOnboarding(payable(0xa64B73699Cc7334810E382A4C09CAEc53636Ab96));

    MagicLP implementation;
    FeeRateModel feeRateModel;
    Factory factory;
    Router router;
    address owner;
    BlastOnboardingBoot onboardingBootstrapper;

    address mim;
    address usdb;

    uint256 mimUnlocked;
    uint256 mimLocked;
    uint256 mimTotal;
    uint256 usdbUnlocked;
    uint256 usdbLocked;
    uint256 usdbTotal;
    uint256 mimUnlockedAfter;
    uint256 mimLockedAfter;
    uint256 mimTotalAfter;
    uint256 usdbUnlockedAfter;
    uint256 usdbLockedAfter;
    uint256 usdbTotalAfter;

    uint256 feeRate = 0.0005 ether; // 0.05%
    uint256 i = 0.998 ether; // 1 MIM = 0.998 USDB
    uint256 k = 0.00025 ether; // 0.00025, 1.25% price fluctuation, similar to A2000 in curve

    function setUp() public override {
        _setup(573967);
    }

    function _setup(uint blockno) private {
        fork(ChainId.Blast, blockno);
        super.setUp();
        mim = toolkit.getAddress(block.chainid, "mim");
        usdb = toolkit.getAddress(block.chainid, "usdb");

        MIMSwapLaunchScript script = new MIMSwapLaunchScript();
        script.setTesting(true);

        address bootstrapper;
        (bootstrapper, implementation, feeRateModel, factory, router) = script.deploy();

        owner = onboarding.owner();

        pushPrank(onboarding.owner());
        onboarding.setBootstrapper(bootstrapper);
        onboardingBootstrapper = BlastOnboardingBoot(address(onboarding));
        onboardingBootstrapper.initialize(router);
        popPrank();
    }

    function testBoot() public {
        vm.expectRevert("UNAUTHORIZED");
        onboardingBootstrapper.bootstrap(0, feeRate, i, k);

        pushPrank(owner);
        // not closed
        vm.expectRevert(abi.encodeWithSignature("ErrWrongState()"));
        onboardingBootstrapper.bootstrap(0, feeRate, i, k);

        popPrank();
        _bootstrap(true);
    }

    function testLockingUserClaimingWithStakingLock() public {
        IMagicLP pool = _bootstrap();
        LockingMultiRewards staking = onboardingBootstrapper.staking();

        uint256 poolBalanceBefore = address(pool).balanceOf(address(onboarding));

        // User with only MIM locked
        address user = 0xfB3485c2e209A5cfBDC1447674256578f1A80eE3;
        pushPrank(user);
        (, mimLocked, ) = onboarding.balances(user, mim);
        (, usdbLocked, ) = onboarding.balances(user, usdb);
        assertGt(mimLocked, 0, "no mim locked");
        uint256 claimableAmount = onboardingBootstrapper.claimable(user);

        // Bootstrapping not ready
        assertEq(claimableAmount, 0, "claimable amount is not 0");

        // Bootstrapping ready
        pushPrank(owner);
        onboardingBootstrapper.setReady(true);
        popPrank();

        claimableAmount = onboardingBootstrapper.claimable(user);
        assertGt(claimableAmount, 0, "claimable amount is 0");

        // verify that the claimable amount share contains the right value given the user only locked MIM
        (uint256 baseAmountOut, uint256 quoteAmountOut) = router.previewRemoveLiquidity(address(pool), claimableAmount);
        quoteAmountOut = DecimalMath.mulFloor(quoteAmountOut, pool._I_());
        assertApproxEqAbs(baseAmountOut + quoteAmountOut, mimLocked, 1.5 ether, "claimable amount doesn't hold locked value");

        // claim and verify it's staked
        vm.expectEmit(true, true, true, true);
        emit LogClaimed(user, claimableAmount, true);
        uint256 claimedAmount = onboardingBootstrapper.claim(true);
        assertEq(claimedAmount, claimableAmount, "claimed amount is not equal to claimable amount");

        uint256 shares = staking.locked(user);
        assertEq(shares, claimedAmount, "shares weren't staked");

        // Claimable should be 0 now
        claimableAmount = onboardingBootstrapper.claimable(user);
        assertEq(claimableAmount, 0, "claimable amount is not 0");

        // Should revert when claiming again
        vm.expectRevert(abi.encodeWithSignature("ErrAlreadyClaimed()"));
        onboardingBootstrapper.claim(true);

        popPrank();

        assertEq(address(pool).balanceOf(address(onboarding)), poolBalanceBefore - claimedAmount, "pool balance is not correct");
    }

    function testLockingUserClaimingWithoutStakingLock() public {
        IMagicLP pool = _bootstrap();
        LockingMultiRewards staking = onboardingBootstrapper.staking();

        uint256 poolBalanceBefore = address(pool).balanceOf(address(onboarding));

        address user = 0xfB3485c2e209A5cfBDC1447674256578f1A80eE3;

        // Bootstrapping ready
        pushPrank(owner);
        onboardingBootstrapper.setReady(true);
        popPrank();

        uint256 claimableAmount = onboardingBootstrapper.claimable(user);

        pushPrank(user);

        // claim and verify it's staked
        vm.expectEmit(true, true, true, true);
        emit LogClaimed(user, claimableAmount, false);
        uint256 claimedAmount = onboardingBootstrapper.claim(false);
        assertEq(claimedAmount, claimableAmount, "claimed amount is not equal to claimable amount");

        uint256 shares = staking.locked(user);
        assertEq(shares, 0, "shares were locked?");

        shares = staking.unlocked(user);
        assertEq(shares, claimedAmount, "shares weren't staked");

        // Claimable should be 0 now
        claimableAmount = onboardingBootstrapper.claimable(user);
        assertEq(claimableAmount, 0, "claimable amount is not 0");

        popPrank();

        assertEq(address(pool).balanceOf(address(onboarding)), poolBalanceBefore - claimedAmount, "pool balance is not correct");
    }

    function testLockingAndUnlockingUserWithStakingLock() public {
        IMagicLP pool = _bootstrap();
        LockingMultiRewards staking = onboardingBootstrapper.staking();

        uint256 poolBalanceBefore = address(pool).balanceOf(address(onboarding));

        address user = 0x9544992B275A7A5A49811B08AAc159Ac1023aa64;

        // Bootstrapping ready
        pushPrank(owner);
        onboardingBootstrapper.setReady(true);
        popPrank();

        uint256 claimableAmount = onboardingBootstrapper.claimable(user);

        pushPrank(user);

        // claim and verify it's staked
        vm.expectEmit(true, true, true, true);
        emit LogClaimed(user, claimableAmount, false);
        uint256 claimedAmount = onboardingBootstrapper.claim(false);
        assertEq(claimedAmount, claimableAmount, "claimed amount is not equal to claimable amount");

        uint256 shares = staking.locked(user);
        assertEq(shares, 0, "shares were locked?");

        shares = staking.unlocked(user);
        assertEq(shares, claimedAmount, "shares weren't staked");

        // Claimable should be 0 now
        claimableAmount = onboardingBootstrapper.claimable(user);
        assertEq(claimableAmount, 0, "claimable amount is not 0");

        (uint256 unlocked, , ) = onboarding.balances(user, mim);
        onboarding.withdraw(mim, unlocked);
        (unlocked, , ) = onboarding.balances(user, mim);
        onboarding.withdraw(usdb, unlocked);

        popPrank();

        assertEq(address(pool).balanceOf(address(onboarding)), poolBalanceBefore - claimedAmount, "pool balance is not correct");
    }

    function testClaimWhenUserNeverLocked() public {
        _setup(381594);
        _bootstrap();
        address user = 0xA537050c62e55bFE38A2eC41f77C898D75Fb864E;

        // No deposit allowed
        deal(mim, user, 1000 ether);
        vm.expectRevert(abi.encodeWithSignature("ErrWrongState()"));
        onboarding.deposit(mim, 1000 ether, true);

        // Bootstrapping ready
        pushPrank(owner);
        onboardingBootstrapper.setReady(true);
        popPrank();

        uint claimable = onboardingBootstrapper.claimable(user);
        assertEq(claimable, 0, "claimable amount is not 0");

        pushPrank(user);
        vm.expectRevert(abi.encodeWithSignature("ErrNothingToClaim()"));
        onboardingBootstrapper.claim(false);

        // try to deposit lock again
        // No deposit allowed
        vm.expectRevert(abi.encodeWithSignature("ErrWrongState()"));
        onboarding.deposit(mim, 1000 ether, true);

        popPrank();
    }

    function testOwnerBalanceOutPool() public {
        _setup(573967);

        // Before bootstrapping we need to deposit some MIM to balance the pool
        pushPrank(alice);
        vm.expectRevert("UNAUTHORIZED");
        onboardingBootstrapper.ownerDeposit(mim, 100);
        vm.expectRevert("UNAUTHORIZED");
        onboardingBootstrapper.ownerWithdraw(mim, 100);
        popPrank();

        (mimUnlocked, mimLocked, mimTotal) = onboarding.totals(mim);
        (usdbUnlocked, usdbLocked, usdbTotal) = onboarding.totals(usdb);
        console2.log("=========BEFORE BALANCING=========");
        console2.log("mimUnlocked", toolkit.formatDecimals(mimUnlocked));
        console2.log("mimLocked", toolkit.formatDecimals(mimLocked));
        console2.log("mimTotal", toolkit.formatDecimals(mimTotal));
        console2.log("---------------------------------");
        console2.log("usdbUnlocked", toolkit.formatDecimals(usdbUnlocked));
        console2.log("usdbLocked", toolkit.formatDecimals(usdbLocked));
        console2.log("usdbTotal", toolkit.formatDecimals(usdbTotal));
        console2.log("=============================================");

        pushPrank(owner);
        onboarding.close();

        uint256 mimAmount = 5_000_000 ether;
        deal(mim, owner, mimAmount);
        mim.safeApprove(address(onboarding), mimAmount);
        onboardingBootstrapper.ownerDeposit(mim, mimAmount);
        popPrank();

        (mimUnlocked, mimLocked, mimTotal) = onboarding.totals(mim);
        (usdbUnlocked, usdbLocked, usdbTotal) = onboarding.totals(usdb);
        console2.log("=========AFTER BALANCING=========");
        console2.log("mimUnlocked", toolkit.formatDecimals(mimUnlocked));
        console2.log("mimLocked", toolkit.formatDecimals(mimLocked));
        console2.log("mimTotal", toolkit.formatDecimals(mimTotal));
        console2.log("---------------------------------");
        console2.log("usdbUnlocked", toolkit.formatDecimals(usdbUnlocked));
        console2.log("usdbLocked", toolkit.formatDecimals(usdbLocked));
        console2.log("usdbTotal", toolkit.formatDecimals(usdbTotal));
        console2.log("=============================================");

        _bootstrap();
    }

    function _bootstrap() internal returns (IMagicLP pool) {
        return _bootstrap(false);
    }

    function _bootstrap(bool debug) internal returns (IMagicLP pool) {
        (, , uint256 previewTotalPoolShares) = onboardingBootstrapper.previewTotalPoolShares(i);

        pushPrank(owner);

        // close event
        if (onboarding.state() != BlastOnboardingData.State.Closed) {
            onboarding.close();
        }

        // bootstrap
        uint256 mimBalanceBefore = mim.balanceOf(address(onboarding));
        uint256 usdbBalanceBefore = usdb.balanceOf(address(onboarding));
        (mimUnlocked, mimLocked, mimTotal) = onboarding.totals(mim);
        (usdbUnlocked, usdbLocked, usdbTotal) = onboarding.totals(usdb);

        if (debug) {
            console2.log("mimBalanceBefore", toolkit.formatDecimals(mimBalanceBefore));
            console2.log("usdbBalanceBefore", toolkit.formatDecimals(usdbBalanceBefore));
            console2.log("---------------------------------");
            console2.log("mimUnlocked", toolkit.formatDecimals(mimUnlocked));
            console2.log("mimLocked", toolkit.formatDecimals(mimLocked));
            console2.log("mimTotal", toolkit.formatDecimals(mimTotal));
            console2.log("---------------------------------");
            console2.log("usdbUnlocked", toolkit.formatDecimals(usdbUnlocked));
            console2.log("usdbLocked", toolkit.formatDecimals(usdbLocked));
            console2.log("usdbTotal", toolkit.formatDecimals(usdbTotal));
        }
        onboardingBootstrapper.bootstrap(0, feeRate, i, k);
        pool = IMagicLP(onboardingBootstrapper.pool());

        uint mimBalanceAfter = mim.balanceOf(address(onboarding));
        uint usdbBalanceAfter = usdb.balanceOf(address(onboarding));
        uint mimBalanceLp = mim.balanceOf(onboardingBootstrapper.pool());
        uint usdbBalanceLp = usdb.balanceOf(onboardingBootstrapper.pool());
        if (debug) {
            console2.log("mimBalanceAfter", toolkit.formatDecimals(mimBalanceAfter));
            console2.log("usdbBalanceAfter", toolkit.formatDecimals(usdbBalanceAfter));
            console2.log("---------------------------------");
            console2.log("mimBalanceLp", toolkit.formatDecimals(mimBalanceLp));
            console2.log("usdbBalanceLp", toolkit.formatDecimals(usdbBalanceLp));
        }
        (mimUnlockedAfter, mimLockedAfter, mimTotalAfter) = onboarding.totals(mim);
        (usdbUnlockedAfter, usdbLockedAfter, usdbTotalAfter) = onboarding.totals(usdb);

        // shouldn't alter the balances
        assertEq(mimUnlocked, mimUnlockedAfter);
        assertEq(mimLocked, mimLockedAfter);
        assertEq(mimTotal, mimTotalAfter);
        assertEq(usdbUnlocked, usdbUnlockedAfter);
        assertEq(usdbLocked, usdbLockedAfter);
        assertEq(usdbTotal, usdbTotalAfter);

        assertApproxEqAbs(mim.balanceOf(address(onboarding)), mimUnlocked, 0.1 ether, "too much mim left");
        assertApproxEqAbs(usdb.balanceOf(address(onboarding)), usdbUnlocked, 0.1 ether, "too much usdb left");

        assertApproxEqRel(mim.balanceOf(onboardingBootstrapper.pool()), mimLocked, 0.001 ether, "imprecised mim balance in pool");
        assertApproxEqRel(usdb.balanceOf(onboardingBootstrapper.pool()), usdbLocked, 0.001 ether, "imprecised usdb balance in pool");

        assertEq(
            mim.balanceOf(onboardingBootstrapper.pool()),
            uint256(IMagicLP(onboardingBootstrapper.pool())._BASE_RESERVE_()),
            "mim balance in pool is not equal to base reserve"
        );
        assertEq(
            usdb.balanceOf(onboardingBootstrapper.pool()),
            uint256(IMagicLP(onboardingBootstrapper.pool())._QUOTE_RESERVE_()),
            "usdb balance in pool is not equal to quote reserve"
        );
        if (debug) {
            console2.log("MIM pool quote balance", toolkit.formatDecimals(mim.balanceOf(address(pool))));
            console2.log("USDB pool quote balance", toolkit.formatDecimals(usdb.balanceOf(address(pool))));

            console2.log("Total pool share amount: %s", onboardingBootstrapper.totalPoolShares());
        }
        
        assertEq(
            onboardingBootstrapper.totalPoolShares(),
            previewTotalPoolShares,
            "total pool shares is not equal to preview total pool shares"
        );
        popPrank();

        // Pool should be paused at first and only owner can use it
        assertEq(pool._PAUSED_(), true, "pool is not paused");
    }
}
