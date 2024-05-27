// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {BaseTest, ChainId} from "utils/BaseTest.sol";
import {TokenBankScript} from "script/TokenBank.s.sol";
import {TokenBank} from "staking/TokenBank.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

contract TokenBankTest is BaseTest {
    using SafeTransferLib for address;

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

    function _mintOSpell(uint256 amount, address to) internal {
        address owner = oSpellBank.owner();
        deal(spell, owner, amount);
        assertEq(spell.balanceOf(address(owner)), 1000 ether);

        pushPrank(owner);
        spell.safeApprove(address(oSpellBank), amount);
        oSpellBank.mint(amount, to);
        popPrank();
    }
}
