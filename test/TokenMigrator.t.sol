// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import "utils/BaseTest.sol";
import {TokenMigrator} from "/periphery/TokenMigrator.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";
import {SymTest} from "halmos-cheatcodes/SymTest.sol";

contract TokenMigratorTest is BaseTest {
    using SafeTransferLib for address;

    TokenMigrator migrator;
    address tokenIn;
    address tokenOut;

    function setUp() public override {
        super.setUp();

        tokenIn = address(new ERC20Mock("TokenIn", "TIN"));
        tokenOut = address(new ERC20Mock("TokenOut", "TOUT"));

        migrator = new TokenMigrator(tokenIn, tokenOut, address(this));

        ERC20Mock(tokenIn).mint(alice, 100_000 ether);
        ERC20Mock(tokenOut).mint(address(migrator), 100_000 ether);
    }

    function testMigrate() public {
        uint256 amountToMigrate = 10_000 ether;

        pushPrank(alice);
        ERC20Mock(tokenIn).approve(address(migrator), amountToMigrate);
        migrator.migrate(amountToMigrate);
        assertEq(ERC20Mock(tokenIn).balanceOf(alice), 90_000 ether);
        assertEq(ERC20Mock(tokenOut).balanceOf(alice), amountToMigrate);
        assertEq(ERC20Mock(tokenIn).balanceOf(address(migrator)), amountToMigrate);
        assertEq(ERC20Mock(tokenOut).balanceOf(address(migrator)), 90_000 ether);
        popPrank();
    }

    function testRecover() public {
        uint256 amountToRecover = 5_000 ether;

        vm.expectRevert("UNAUTHORIZED");
        vm.prank(alice);
        migrator.recover(tokenOut, amountToRecover, alice);

        vm.prank(migrator.owner());
        migrator.recover(tokenOut, amountToRecover, address(this));

        assertEq(ERC20Mock(tokenOut).balanceOf(address(this)), amountToRecover);
        assertEq(ERC20Mock(tokenOut).balanceOf(address(migrator)), 95_000 ether);
    }
}

contract TokenMigratorSymTest is SymTest, Test {
    using SafeTransferLib for address;

    TokenMigrator migrator;
    address tokenIn;
    address tokenOut;
    address tokenOther;
    address owner;

    function setUp() public {
        tokenIn = address(new ERC20Mock("TokenIn", "TIN"));
        tokenOut = address(new ERC20Mock("TokenOut", "TOUT"));
        tokenOther = address(new ERC20Mock("TokenOther", "TOTHER"));

        svm.enableSymbolicStorage(address(tokenIn));
        svm.enableSymbolicStorage(address(tokenOut));
        svm.enableSymbolicStorage(address(tokenOther));

        owner = svm.createAddress("Owner");

        migrator = new TokenMigrator(tokenIn, tokenOut, owner);
    }

    function proveMigrationBalance(address alice, uint256 amountToMigrate) public {
        uint256 aliceTokenInBalance = tokenIn.balanceOf(alice);
        uint256 aliceTokenOutBalance = tokenOut.balanceOf(alice);
        uint256 tokenMigratorInBalance = tokenIn.balanceOf(address(migrator));
        uint256 tokenMigratorOutBalance = tokenOut.balanceOf(address(migrator));

        vm.assume(alice != address(migrator));

        vm.prank(alice);
        migrator.migrate(amountToMigrate);

        assertEq(tokenIn.balanceOf(alice), aliceTokenInBalance - amountToMigrate);
        assertEq(tokenOut.balanceOf(alice), aliceTokenOutBalance + amountToMigrate);
        assertEq(tokenIn.balanceOf(address(migrator)), tokenMigratorInBalance + amountToMigrate);
        assertEq(tokenOut.balanceOf(address(migrator)), tokenMigratorOutBalance - amountToMigrate);
    }

    function proveMigrateEnoughBalanceNeverRevert(address alice, uint256 amountToMigrate) public {
        vm.assume(alice != address(migrator) && alice != address(0));
        vm.assume(tokenIn.balanceOf(alice) >= amountToMigrate);
        vm.assume(ERC20Mock(tokenIn).allowance(alice, address(migrator)) >= amountToMigrate);
        vm.assume(tokenOut.balanceOf(address(migrator)) >= amountToMigrate);

        vm.prank(alice);
        (bool success, ) = address(migrator).call(abi.encodeWithSelector(migrator.migrate.selector, amountToMigrate));
        assertTrue(success);
    }

    function proveOnlyOwnerRecover(address alice, address token, uint256 amount, address to) public {
        vm.prank(alice);
        migrator.recover(token, amount, to);
        assertEq(alice, owner);
    }

    function proveOwnerRecoverAnything(address token, uint256 amount, address to) public {
        vm.assume(to != address(migrator));

        uint256 tokenBalance = token.balanceOf(to);

        vm.prank(owner);
        migrator.recover(token, amount, to);
        assertEq(token.balanceOf(to), tokenBalance + amount);
    }

    function proveRecoverEnoughBalanceNeverRevert(address token, uint256 amount, address to) public {
        vm.assume(to != address(0));
        vm.assume(amount > 0);
        vm.assume(token.balanceOf(address(migrator)) > amount);

        vm.prank(owner);
        (bool success, ) = address(migrator).call(abi.encodeWithSelector(migrator.recover.selector, token, amount, to));
        assertTrue(success);
    }
}
