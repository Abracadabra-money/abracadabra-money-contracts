// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/BlastOnboarding.s.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";
import {BlastOnboardingData} from "/blast/BlastOnboarding.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

contract BlastOnboardingBootstrapper is BlastOnboardingData {
    bool public bootstrapped;

    function bootstrap() external onlyOwner onlyState(State.Closed) {
        bootstrapped = true;
    }
}

contract BlastOnboardingTest is BaseTest {
    using SafeTransferLib for address;

    BlastOnboarding onboarding;
    address[] tokens;
    address usdb;
    address mim;

    function setUp() public override {
        fork(ChainId.Blast, 219772);
        super.setUp();
        BlastMock(0x4300000000000000000000000000000000000002).enableYieldTokenMocks();

        BlastOnboardingScript script = new BlastOnboardingScript();
        script.setTesting(true);

        usdb = toolkit.getAddress(ChainId.Blast, "usdb");
        mim = toolkit.getAddress(ChainId.Blast, "mim");

        tokens.push(usdb);
        tokens.push(mim);

        (onboarding) = script.deploy();

        pushPrank(onboarding.owner());
        onboarding.setTokenSupported(usdb, true);
        onboarding.setTokenSupported(mim, true);
        onboarding.open();
        popPrank();
    }

    function testPausable() public {
        address owner = onboarding.owner();

        pushPrank(alice);
        deal(usdb, alice, 100_000_000_000 ether, true);
        usdb.safeApprove(address(onboarding), type(uint).max);
        onboarding.deposit(usdb, 1 ether, false);
        onboarding.deposit(usdb, 1 ether, true);
        popPrank();

        // pause
        vm.prank(owner);
        onboarding.pause();

        pushPrank(alice);
        vm.expectRevert("Pausable: paused");
        onboarding.deposit(usdb, 1 ether, false);
        vm.expectRevert("Pausable: paused");
        onboarding.withdraw(usdb, 1 ether);
        vm.expectRevert("Pausable: paused");
        onboarding.lock(usdb, 1 ether);
        popPrank();

        // unpause
        vm.prank(owner);
        onboarding.unpause();

        pushPrank(alice);
        onboarding.deposit(usdb, 1 ether, false);
        onboarding.withdraw(usdb, 1 ether);
        onboarding.lock(usdb, 1 ether);
        popPrank();
    }

    function testUpgradeProxy() public {
        BlastOnboardingBootstrapper proxy = new BlastOnboardingBootstrapper();

        pushPrank(onboarding.owner());
        onboarding.setBootstrapper(address(proxy));
        assertEq(address(onboarding.bootstrapper()), address(proxy));
        assertEq(uint8(onboarding.state()), 1);
        popPrank();

        assertEq(BlastOnboardingBootstrapper(address(onboarding)).bootstrapped(), false);

        pushPrank(alice);
        vm.expectRevert();
        BlastOnboardingBootstrapper(address(onboarding)).bootstrap();
        popPrank();

        pushPrank(onboarding.owner());
        vm.expectRevert(abi.encodeWithSignature("ErrWrongState()"));
        BlastOnboardingBootstrapper(address(onboarding)).bootstrap();
        onboarding.close();
        BlastOnboardingBootstrapper(address(onboarding)).bootstrap();
        assertEq(BlastOnboardingBootstrapper(address(onboarding)).bootstrapped(), true);
        assertEq(address(onboarding.bootstrapper()), address(proxy));
        assertEq(uint8(onboarding.state()), 2);
        popPrank();
    }

    function testCap() public {
        uint256 cap = 100_000_000 ether;
        pushPrank(onboarding.owner());
        onboarding.setCap(usdb, cap);
        assertEq(onboarding.caps(usdb), cap);
        assertEq(onboarding.caps(mim), 0);
        popPrank();

        pushPrank(alice);
        deal(usdb, alice, 100_000_000_000 ether, true);
        usdb.safeApprove(address(onboarding), type(uint).max);
        onboarding.deposit(usdb, cap, false);

        vm.expectRevert(abi.encodeWithSignature("ErrCapReached()"));
        onboarding.deposit(usdb, 1, true);
        onboarding.deposit(usdb, 0, true);
        popPrank();
    }

    // Simply put here to avoid stack too deep error
    uint8 action;
    uint256 amount;
    uint256 tokenIndex;
    address token;
    uint256 percentAmount;
    uint256 userUnlockedBefore;
    uint256 userLockedBefore;
    uint256 userTotalBefore;
    uint256 totalUnlockedBefore;
    uint256 totalLockedBefore;
    uint256 totalBefore;
    uint256 scaledUnlockedAmount;
    uint256 userUnlockedAfter;
    uint256 userLockedAfter;
    uint256 userTotalAfter;
    uint256 totalUnlockedAfter;
    uint256 totalLockedAfter;
    uint256 totalAfter;

    function testFuzz(
        address[100] memory users,
        uint256[100] memory amounts,
        uint256[100] memory tokenIndexes,
        uint8[100] memory actions
    ) public {
        for (uint256 i = 0; i < actions.length; i++) {
            if (users[i] == address(0) || users[i] == address(onboarding)) {
                continue;
            }

            pushPrank(users[i]);

            action = uint8(bound(actions[i], 0, 3));
            amount = bound(amounts[i], 0, 100_000_000 ether);
            tokenIndex = bound(tokenIndexes[i], 0, tokens.length - 1);
            token = tokens[tokenIndex];
            percentAmount = (amount * 1e18) / 100_000_000 ether;

            console2.log("action", action);
            console2.log("amount", amount);
            console2.log("tokenIndex", tokenIndex);
            console2.log("token", token);
            console2.log("percentAmount", percentAmount);

            (userUnlockedBefore, userLockedBefore, userTotalBefore) = onboarding.balances(users[i], token);
            (totalUnlockedBefore, totalLockedBefore, totalBefore) = onboarding.totals(token);

            // used to scale the fuzzed amount to the user's unlocked amount using a ratio over the max uint256
            scaledUnlockedAmount = (userUnlockedBefore * percentAmount) / 1e18;

            uint256 balanceTokenBefore = token.balanceOf(address(onboarding));

            // 0: deposit, no lock
            if (action == 0) {
                deal(token, users[i], amount, true);
                uint256 balanceBefore = token.balanceOf(users[i]);
                token.safeApprove(address(onboarding), amount);
                onboarding.deposit(token, amount, false);

                uint256 balanceAfter = token.balanceOf(users[i]);
                assertEq(balanceBefore, balanceAfter + amount);

                (userUnlockedAfter, userLockedAfter, userTotalAfter) = onboarding.balances(users[i], token);
                (totalUnlockedAfter, totalLockedAfter, totalAfter) = onboarding.totals(token);

                assertEq(userUnlockedAfter, userUnlockedBefore + amount);
                assertEq(userLockedAfter, userLockedBefore);
                assertEq(userTotalAfter, userTotalBefore + amount);
                assertEq(totalUnlockedAfter, totalUnlockedBefore + amount);
                assertEq(totalLockedAfter, totalLockedBefore);
                assertEq(totalAfter, totalBefore + amount);
                assertEq(token.balanceOf(address(onboarding)), balanceTokenBefore + amount);
            }
            // 1: deposit, lock
            else if (action == 1) {
                deal(token, users[i], amount, true);
                uint256 balanceBefore = token.balanceOf(users[i]);
                token.safeApprove(address(onboarding), amount);
                onboarding.deposit(token, amount, true);
                uint256 balanceAfter = token.balanceOf(users[i]);
                assertEq(balanceBefore, balanceAfter + amount);

                (userUnlockedAfter, userLockedAfter, userTotalAfter) = onboarding.balances(users[i], token);
                (totalUnlockedAfter, totalLockedAfter, totalAfter) = onboarding.totals(token);

                assertEq(userUnlockedAfter, userUnlockedBefore);
                assertEq(userLockedAfter, userLockedBefore + amount);
                assertEq(userTotalAfter, userTotalBefore + amount);
                assertEq(totalUnlockedAfter, totalUnlockedBefore);
                assertEq(totalLockedAfter, totalLockedBefore + amount);
                assertEq(totalAfter, totalBefore + amount);
                assertEq(token.balanceOf(address(onboarding)), balanceTokenBefore + amount);
            }
            // 2: lock unlocked
            else if (action == 2) {
                if (scaledUnlockedAmount > 0) {
                    onboarding.lock(token, scaledUnlockedAmount);

                    (userUnlockedAfter, userLockedAfter, userTotalAfter) = onboarding.balances(users[i], token);
                    (totalUnlockedAfter, totalLockedAfter, totalAfter) = onboarding.totals(token);

                    assertEq(userUnlockedAfter, userUnlockedBefore - scaledUnlockedAmount);
                    assertEq(userLockedAfter, userLockedBefore + scaledUnlockedAmount);
                    assertEq(userTotalAfter, userTotalBefore);
                    assertEq(totalUnlockedAfter, totalUnlockedBefore - scaledUnlockedAmount);
                    assertEq(totalLockedAfter, totalLockedBefore + scaledUnlockedAmount);
                    assertEq(totalAfter, totalBefore);
                    assertEq(token.balanceOf(address(onboarding)), balanceTokenBefore);
                }
            }
            // 3: withdraw
            else if (action == 3) {
                if (scaledUnlockedAmount > 0) {
                    onboarding.withdraw(token, scaledUnlockedAmount);

                    (userUnlockedAfter, userLockedAfter, userTotalAfter) = onboarding.balances(users[i], token);
                    (totalUnlockedAfter, totalLockedAfter, totalAfter) = onboarding.totals(token);

                    assertEq(userUnlockedAfter, userUnlockedBefore - scaledUnlockedAmount);
                    assertEq(userLockedAfter, userLockedBefore);
                    assertEq(userTotalAfter, userTotalBefore - scaledUnlockedAmount);
                    assertEq(totalUnlockedAfter, totalUnlockedBefore - scaledUnlockedAmount);
                    assertEq(totalLockedAfter, totalLockedBefore);
                    assertEq(totalAfter, totalBefore - scaledUnlockedAmount);
                    assertEq(token.balanceOf(address(onboarding)), balanceTokenBefore - scaledUnlockedAmount);
                }
            }

            popPrank();
        }
    }
}
