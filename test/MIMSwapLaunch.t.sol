// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/MIMSwapLaunch.s.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {BlastOnboarding} from "/blast/BlastOnboarding.sol";
import {BlastOnboardingBoot} from "/blast/BlastOnboardingBoot.sol";
import {IMagicLP} from "/mimswap/interfaces/IMagicLP.sol";
import {DecimalMath} from "/mimswap/libraries/DecimalMath.sol";
import {LockingMultiRewards} from "staking/LockingMultiRewards.sol";

contract MIMSwapLaunchTest is BaseTest {
    using SafeTransferLib for address;

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

    function setUp() public override {
        fork(ChainId.Blast, 301962);
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
        onboardingBootstrapper.bootstrap(0);

        pushPrank(owner);
        // not closed
        vm.expectRevert(abi.encodeWithSignature("ErrWrongState()"));
        onboardingBootstrapper.bootstrap(0);

        popPrank();
        _bootstrap();
    }

    function testClaiming() public {
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
        assertApproxEqAbs(baseAmountOut + quoteAmountOut, mimLocked, 1 ether, "claimable amount doesn't old locked value");

        // claim and verify it's staked
        uint256 claimedAmount = onboardingBootstrapper.claim();
        assertEq(claimedAmount, claimableAmount, "claimed amount is not equal to claimable amount");

        uint256 shares = staking.locked(user);
        assertEq(shares, claimedAmount, "shares weren't staked");

        // Claimable should be 0 now
        claimableAmount = onboardingBootstrapper.claimable(user);
        assertEq(claimableAmount, 0, "claimable amount is not 0");

        // Should revert when claiming again
        vm.expectRevert(abi.encodeWithSignature("ErrAlreadyClaimed()"));
        onboardingBootstrapper.claim();

        popPrank();

        assertEq(address(pool).balanceOf(address(onboarding)), poolBalanceBefore - claimedAmount, "pool balance is not correct");
    }

    function _bootstrap() internal returns(IMagicLP pool) {
        pushPrank(owner);
        // close event
        onboarding.close();

        // bootstrap
        uint256 mimBalanceBefore = mim.balanceOf(address(onboarding));
        uint256 usdbBalanceBefore = usdb.balanceOf(address(onboarding));
        (mimUnlocked, mimLocked, mimTotal) = onboarding.totals(mim);
        (usdbUnlocked, usdbLocked, usdbTotal) = onboarding.totals(usdb);

        console2.log("mimBalanceBefore", mimBalanceBefore, mimBalanceBefore / 1e18);
        console2.log("usdbBalanceBefore", usdbBalanceBefore, usdbBalanceBefore / 1e18);
        console2.log("---------------------------------");
        console2.log("mimUnlocked", mimUnlocked, mimUnlocked / 1e18);
        console2.log("mimLocked", mimLocked, mimLocked / 1e18);
        console2.log("mimTotal", mimTotal, mimTotal / 1e18);
        console2.log("---------------------------------");
        console2.log("usdbUnlocked", usdbUnlocked, usdbUnlocked / 1e18);
        console2.log("usdbLocked", usdbLocked, usdbLocked / 1e18);
        console2.log("usdbTotal", usdbTotal, usdbTotal / 1e18);

        onboardingBootstrapper.bootstrap(0);
        pool = IMagicLP(onboardingBootstrapper.pool());
        
        uint mimBalanceAfter = mim.balanceOf(address(onboarding));
        uint usdbBalanceAfter = usdb.balanceOf(address(onboarding));
        uint mimBalanceLp = mim.balanceOf(onboardingBootstrapper.pool());
        uint usdbBalanceLp = usdb.balanceOf(onboardingBootstrapper.pool());

        console2.log("mimBalanceAfter", mimBalanceAfter, mimBalanceAfter / 1e18);
        console2.log("usdbBalanceAfter", usdbBalanceAfter, usdbBalanceAfter / 1e18);
        console2.log("---------------------------------");
        console2.log("mimBalanceLp", mimBalanceLp, mimBalanceLp / 1e18);
        console2.log("usdbBalanceLp", usdbBalanceLp, usdbBalanceLp / 1e18);

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

        popPrank();
    }
}
