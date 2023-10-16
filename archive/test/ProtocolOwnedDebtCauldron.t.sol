// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/ProtocolOwnedDebtCauldron.s.sol";

contract ProtocolOwnedDebtCauldronTest is BaseTest {
    ProtocolOwnedDebtCauldron public cauldron;

    event LogBorrow(address indexed from, address indexed to, uint256 amount, uint256 part);
    event LogRepay(address indexed from, address indexed to, uint256 amount, uint256 part);

    function setUp() public override {
        fork(ChainId.Mainnet, 15371985);
        super.setUp();

        ProtocolOwnedDebtCauldronScript script = new ProtocolOwnedDebtCauldronScript();
        script.setTesting(true);
        (cauldron) = script.deploy();
        vm.startPrank(cauldron.multisig());
        cauldron.magicInternetMoney().approve(address(cauldron), 10 * 1e6 * 1e18);
        vm.stopPrank();
    }

    function testCauldronBorrow() public {
        uint256 balanceBefore = cauldron.magicInternetMoney().balanceOf(cauldron.safe());
        vm.startPrank(cauldron.safe());
        uint256 amount = 10 * 1e6 * 1e18;
        vm.expectEmit(true, true, true, true);
        emit LogBorrow(cauldron.safe(), cauldron.safe(), amount, amount);

        cauldron.borrow(amount);
        vm.stopPrank();
        uint256 balanceDelta = cauldron.magicInternetMoney().balanceOf(cauldron.safe()) - balanceBefore;
        assertEq(balanceDelta, amount);
        assertEq(cauldron.userBorrowPart(cauldron.safe()), amount);
        (uint256 elastic, uint256 base) = cauldron.totalBorrow();
        assertEq(elastic, amount);
        assertEq(base, amount);
    }

    function testCauldronRepay() public {
        uint256 balanceBefore = cauldron.magicInternetMoney().balanceOf(cauldron.safe());
        uint256 balanceBeforeMultisig = cauldron.magicInternetMoney().balanceOf(cauldron.multisig());
        vm.startPrank(cauldron.safe());
        uint256 amount = 10 * 1e6 * 1e18;
        cauldron.borrow(amount);
        cauldron.magicInternetMoney().approve(address(cauldron),amount);
        vm.expectEmit(true, true, true, true);
        emit LogRepay(cauldron.safe(), cauldron.safe(), amount, amount);
        cauldron.repay(amount);
        vm.stopPrank();
        uint256 balanceDelta = cauldron.magicInternetMoney().balanceOf(cauldron.safe()) - balanceBefore;
        assertEq(balanceDelta, 0);
        balanceDelta = cauldron.magicInternetMoney().balanceOf(cauldron.multisig()) - balanceBeforeMultisig;
        assertEq(balanceDelta, 0);
        assertEq(cauldron.userBorrowPart(cauldron.safe()), 0);
        (uint256 elastic, uint256 base) = cauldron.totalBorrow();
        assertEq(elastic, 0);
        assertEq(base, 0);
    }
}
