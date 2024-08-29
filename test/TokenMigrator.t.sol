// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import "utils/BaseTest.sol";
import {TokenMigrator} from "/periphery/TokenMigrator.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";

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

contract TokenMigratorSymTest is Test {
    TokenMigrator migrator;
    address tokenIn;
    address tokenOut;

    function setUp() public {
        tokenIn = address(new ERC20Mock("TokenIn", "TIN"));
        tokenOut = address(new ERC20Mock("TokenOut", "TOUT"));

        migrator = new TokenMigrator(tokenIn, tokenOut, address(this));
    }

    function proveMigrationBalance(
        address alice,
        uint256 aliceTokenInBalance,
        uint256 aliceTokenInMigratorAllowance,
        uint256 tokenMigratorOutBalance,
        uint256 amountToMigrate
    ) public {
        vm.assume(alice != address(migrator) && alice != tokenIn && alice != tokenOut);

        ERC20Mock(tokenIn).mint(alice, aliceTokenInBalance);
        ERC20Mock(tokenOut).mint(address(migrator), tokenMigratorOutBalance);

        vm.startPrank(alice);
        ERC20Mock(tokenIn).approve(address(migrator), aliceTokenInMigratorAllowance);
        migrator.migrate(amountToMigrate);
        vm.stopPrank();

        assertEq(ERC20Mock(tokenIn).balanceOf(alice), aliceTokenInBalance - amountToMigrate);
        assertEq(ERC20Mock(tokenOut).balanceOf(alice), amountToMigrate);
        assertEq(ERC20Mock(tokenIn).balanceOf(address(migrator)), amountToMigrate);
        assertEq(ERC20Mock(tokenOut).balanceOf(address(migrator)), tokenMigratorOutBalance - amountToMigrate);
    }
}
