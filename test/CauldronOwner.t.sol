// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {BaseTest, ChainId} from "utils/BaseTest.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {BoringOwnable} from "BoringSolidity/BoringOwnable.sol";
import {CauldronOwnerScript} from "script/CauldronOwner.s.sol";
import {CauldronOwner} from "periphery/CauldronOwner.sol";
import {CauldronRegistry, CauldronInfo} from "periphery/CauldronRegistry.sol";
import {ICauldronV2} from "interfaces/ICauldronV2.sol";
import {ICauldronV3} from "interfaces/ICauldronV3.sol";
import {ICauldronV4} from "interfaces/ICauldronV4.sol";

contract CauldronOwnerTest is BaseTest {
    CauldronOwner cauldronOwner;

    function setUp() public override {
        fork(ChainId.Arbitrum, 211878566);
        super.setUp();

        CauldronOwnerScript script = new CauldronOwnerScript();
        script.setTesting(true);

        (cauldronOwner) = script.deploy();

        _changeCauldronOwners();
    }

    function testReduceSupply() public {
        CauldronRegistry registry = CauldronRegistry(toolkit.getAddress(ChainId.All, "cauldronRegistry"));
        uint length = registry.length();

        pushPrank(alice);
        for (uint i = 0; i < length; i++) {
            CauldronInfo memory info = registry.get(i);
            ICauldronV2 cauldron = ICauldronV2(info.cauldron);
            vm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
            cauldronOwner.reduceSupply(cauldron, 0);
        }

        // grant ROLE_REDUCE_SUPPLY permission
        pushPrank(cauldronOwner.owner());
        cauldronOwner.grantRoles(alice, cauldronOwner.ROLE_REDUCE_SUPPLY());
        popPrank();

        for (uint i = 0; i < length; i++) {
            CauldronInfo memory info = registry.get(i);
            ICauldronV2 cauldron = ICauldronV2(info.cauldron);
            cauldronOwner.reduceSupply(cauldron, 0);
        }

        // revoke ROLE_REDUCE_SUPPLY permission
        pushPrank(cauldronOwner.owner());
        cauldronOwner.revokeRoles(alice, cauldronOwner.ROLE_REDUCE_SUPPLY());
        popPrank();

        pushPrank(alice);
        for (uint i = 0; i < length; i++) {
            CauldronInfo memory info = registry.get(i);
            ICauldronV2 cauldron = ICauldronV2(info.cauldron);
            vm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
            cauldronOwner.reduceSupply(cauldron, 0);
        }

        // grant ROLE_OPERATOR permission
        pushPrank(cauldronOwner.owner());
        cauldronOwner.grantRoles(alice, cauldronOwner.ROLE_OPERATOR());
        popPrank();

        for (uint i = 0; i < length; i++) {
            CauldronInfo memory info = registry.get(i);
            ICauldronV2 cauldron = ICauldronV2(info.cauldron);
            cauldronOwner.reduceSupply(cauldron, 0);
        }

        // revoke ROLE_REDUCE_SUPPLY permission
        pushPrank(cauldronOwner.owner());
        cauldronOwner.revokeRoles(alice, cauldronOwner.ROLE_OPERATOR());
        popPrank();

        for (uint i = 0; i < length; i++) {
            CauldronInfo memory info = registry.get(i);
            ICauldronV2 cauldron = ICauldronV2(info.cauldron);
            vm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
            cauldronOwner.reduceSupply(cauldron, 0);
        }

        popPrank();
    }

    function testReduceCompletly() public {
        CauldronRegistry registry = CauldronRegistry(toolkit.getAddress(ChainId.All, "cauldronRegistry"));
        uint length = registry.length();

        pushPrank(alice);
        for (uint i = 0; i < length; i++) {
            CauldronInfo memory info = registry.get(i);
            ICauldronV2 cauldron = ICauldronV2(info.cauldron);
            vm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
            cauldronOwner.reduceCompletely(cauldron);
        }

        // grant ROLE_REDUCE_SUPPLY permission
        pushPrank(cauldronOwner.owner());
        cauldronOwner.grantRoles(alice, cauldronOwner.ROLE_REDUCE_SUPPLY());
        popPrank();

        for (uint i = 0; i < length; i++) {
            CauldronInfo memory info = registry.get(i);
            ICauldronV2 cauldron = ICauldronV2(info.cauldron);
            cauldronOwner.reduceCompletely(cauldron);
        }

        // revoke ROLE_REDUCE_SUPPLY permission
        pushPrank(cauldronOwner.owner());
        cauldronOwner.revokeRoles(alice, cauldronOwner.ROLE_REDUCE_SUPPLY());
        popPrank();

        pushPrank(alice);
        for (uint i = 0; i < length; i++) {
            CauldronInfo memory info = registry.get(i);
            ICauldronV2 cauldron = ICauldronV2(info.cauldron);
            vm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
            cauldronOwner.reduceCompletely(cauldron);
        }

        // grant ROLE_OPERATOR permission
        pushPrank(cauldronOwner.owner());
        cauldronOwner.grantRoles(alice, cauldronOwner.ROLE_OPERATOR());
        popPrank();

        for (uint i = 0; i < length; i++) {
            CauldronInfo memory info = registry.get(i);
            ICauldronV2 cauldron = ICauldronV2(info.cauldron);
            cauldronOwner.reduceCompletely(cauldron);
        }

        // revoke ROLE_REDUCE_SUPPLY permission
        pushPrank(cauldronOwner.owner());
        cauldronOwner.revokeRoles(alice, cauldronOwner.ROLE_OPERATOR());
        popPrank();

        for (uint i = 0; i < length; i++) {
            CauldronInfo memory info = registry.get(i);
            ICauldronV2 cauldron = ICauldronV2(info.cauldron);
            vm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
            cauldronOwner.reduceCompletely(cauldron);
        }
    }

    function testDisableBorrowing() public {
        CauldronRegistry registry = CauldronRegistry(toolkit.getAddress(ChainId.All, "cauldronRegistry"));
        uint length = registry.length();

        pushPrank(alice);
        for (uint i = 0; i < length; i++) {
            CauldronInfo memory info = registry.get(i);
            vm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
            cauldronOwner.disableBorrowing(info.cauldron);
        }

        // grant ROLE_DISABLE_BORROWING permission
        pushPrank(cauldronOwner.owner());
        cauldronOwner.grantRoles(alice, cauldronOwner.ROLE_DISABLE_BORROWING());
        popPrank();

        for (uint i = 0; i < length; i++) {
            CauldronInfo memory info = registry.get(i);
            cauldronOwner.disableBorrowing(info.cauldron);
        }

        // revoke ROLE_DISABLE_BORROWING permission
        pushPrank(cauldronOwner.owner());
        cauldronOwner.revokeRoles(alice, cauldronOwner.ROLE_DISABLE_BORROWING());
        popPrank();

        pushPrank(alice);
        for (uint i = 0; i < length; i++) {
            CauldronInfo memory info = registry.get(i);
            vm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
            cauldronOwner.disableBorrowing(info.cauldron);
        }

        // grant ROLE_OPERATOR permission
        pushPrank(cauldronOwner.owner());
        cauldronOwner.grantRoles(alice, cauldronOwner.ROLE_OPERATOR());
        popPrank();

        for (uint i = 0; i < length; i++) {
            CauldronInfo memory info = registry.get(i);
            cauldronOwner.disableBorrowing(info.cauldron);
        }

        // revoke ROLE_DISABLE_BORROWING permission
        pushPrank(cauldronOwner.owner());
        cauldronOwner.revokeRoles(alice, cauldronOwner.ROLE_OPERATOR());
        popPrank();

        for (uint i = 0; i < length; i++) {
            CauldronInfo memory info = registry.get(i);
            vm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
            cauldronOwner.disableBorrowing(info.cauldron);
        }
    }

    function testDisableAllBorrowing() public {
        pushPrank(alice);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
        cauldronOwner.disableAllBorrowing();

        // grant ROLE_DISABLE_BORROWING permission
        pushPrank(cauldronOwner.owner());
        cauldronOwner.grantRoles(alice, cauldronOwner.ROLE_DISABLE_BORROWING());
        popPrank();

        cauldronOwner.disableAllBorrowing();

        // revoke ROLE_DISABLE_BORROWING permission
        pushPrank(cauldronOwner.owner());
        cauldronOwner.revokeRoles(alice, cauldronOwner.ROLE_DISABLE_BORROWING());
        popPrank();

        pushPrank(alice);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
        cauldronOwner.disableAllBorrowing();

        // grant ROLE_OPERATOR permission
        pushPrank(cauldronOwner.owner());
        cauldronOwner.grantRoles(alice, cauldronOwner.ROLE_OPERATOR());
        popPrank();

        cauldronOwner.disableAllBorrowing();

        // revoke ROLE_DISABLE_BORROWING permission
        pushPrank(cauldronOwner.owner());
        cauldronOwner.revokeRoles(alice, cauldronOwner.ROLE_OPERATOR());
        popPrank();

        pushPrank(alice);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
        cauldronOwner.disableAllBorrowing();
    }

    function testChangeInterestRate() public {
        CauldronRegistry registry = CauldronRegistry(toolkit.getAddress(ChainId.All, "cauldronRegistry"));
        uint length = registry.length();

        pushPrank(alice);
        for (uint i = 0; i < length; i++) {
            CauldronInfo memory info = registry.get(i);
            if (info.version < 3) continue;

            ICauldronV3 cauldron = ICauldronV3(info.cauldron);
            vm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
            cauldronOwner.changeInterestRate(cauldron, 0);
        }

        advanceTime(7 days);

        // grant ROLE_CHANGE_INTEREST_RATE permission
        pushPrank(cauldronOwner.owner());
        cauldronOwner.grantRoles(alice, cauldronOwner.ROLE_CHANGE_INTEREST_RATE());
        popPrank();

        for (uint i = 0; i < length; i++) {
            CauldronInfo memory info = registry.get(i);
            if (info.version < 3) continue;

            ICauldronV3 cauldron = ICauldronV3(info.cauldron);
            cauldronOwner.changeInterestRate(cauldron, 0);
        }

        advanceTime(7 days);

        // revoke ROLE_CHANGE_INTEREST_RATE permission
        pushPrank(cauldronOwner.owner());
        cauldronOwner.revokeRoles(alice, cauldronOwner.ROLE_CHANGE_INTEREST_RATE());
        popPrank();

        pushPrank(alice);
        for (uint i = 0; i < length; i++) {
            CauldronInfo memory info = registry.get(i);
            if (info.version < 3) continue;

            ICauldronV3 cauldron = ICauldronV3(info.cauldron);
            vm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
            cauldronOwner.changeInterestRate(cauldron, 0);
        }

        advanceTime(7 days);

        // grant ROLE_OPERATOR permission
        pushPrank(cauldronOwner.owner());
        cauldronOwner.grantRoles(alice, cauldronOwner.ROLE_OPERATOR());
        popPrank();

        for (uint i = 0; i < length; i++) {
            CauldronInfo memory info = registry.get(i);
            if (info.version < 3) continue;

            ICauldronV3 cauldron = ICauldronV3(info.cauldron);
            cauldronOwner.changeInterestRate(cauldron, 0);
        }

        advanceTime(7 days);

        // revoke ROLE_CHANGE_INTEREST_RATE permission
        pushPrank(cauldronOwner.owner());
        cauldronOwner.revokeRoles(alice, cauldronOwner.ROLE_OPERATOR());
        popPrank();

        for (uint i = 0; i < length; i++) {
            CauldronInfo memory info = registry.get(i);
            if (info.version < 3) continue;

            ICauldronV3 cauldron = ICauldronV3(info.cauldron);
            vm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
            cauldronOwner.changeInterestRate(cauldron, 0);
        }
    }

    function testChangeBorrowLimit() public {
        CauldronRegistry registry = CauldronRegistry(toolkit.getAddress(ChainId.All, "cauldronRegistry"));
        uint length = registry.length();

        pushPrank(alice);
        for (uint i = 0; i < length; i++) {
            CauldronInfo memory info = registry.get(i);
            if (info.version < 3) continue;

            ICauldronV3 cauldron = ICauldronV3(info.cauldron);
            vm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
            cauldronOwner.changeBorrowLimit(cauldron, 0, 0);
        }

        // grant ROLE_CHANGE_BORROW_LIMIT permission
        pushPrank(cauldronOwner.owner());
        cauldronOwner.grantRoles(alice, cauldronOwner.ROLE_CHANGE_BORROW_LIMIT());
        popPrank();

        for (uint i = 0; i < length; i++) {
            CauldronInfo memory info = registry.get(i);
            if (info.version < 3) continue;

            ICauldronV3 cauldron = ICauldronV3(info.cauldron);
            cauldronOwner.changeBorrowLimit(cauldron, 0, 0);
        }

        // revoke ROLE_CHANGE_BORROW_LIMIT permission
        pushPrank(cauldronOwner.owner());
        cauldronOwner.revokeRoles(alice, cauldronOwner.ROLE_CHANGE_BORROW_LIMIT());
        popPrank();

        pushPrank(alice);
        for (uint i = 0; i < length; i++) {
            CauldronInfo memory info = registry.get(i);
            if (info.version < 3) continue;

            ICauldronV3 cauldron = ICauldronV3(info.cauldron);
            vm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
            cauldronOwner.changeBorrowLimit(cauldron, 0, 0);
        }

        // grant ROLE_OPERATOR permission
        pushPrank(cauldronOwner.owner());
        cauldronOwner.grantRoles(alice, cauldronOwner.ROLE_OPERATOR());
        popPrank();

        for (uint i = 0; i < length; i++) {
            CauldronInfo memory info = registry.get(i);
            if (info.version < 3) continue;

            ICauldronV3 cauldron = ICauldronV3(info.cauldron);
            cauldronOwner.changeBorrowLimit(cauldron, 0, 0);
        }
    }

    function testSetBlacklistedCallee() public {
        CauldronRegistry registry = CauldronRegistry(toolkit.getAddress(ChainId.All, "cauldronRegistry"));
        uint length = registry.length();

        pushPrank(alice);
        for (uint i = 0; i < length; i++) {
            CauldronInfo memory info = registry.get(i);
            if (info.version < 4) continue;

            ICauldronV4 cauldron = ICauldronV4(info.cauldron);
            vm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
            cauldronOwner.setBlacklistedCallee(cauldron, address(0), false);
        }

        // grant ROLE_SET_BLACKLISTED_CALLEE permission
        pushPrank(cauldronOwner.owner());
        cauldronOwner.grantRoles(alice, cauldronOwner.ROLE_SET_BLACKLISTED_CALLEE());
        popPrank();

        for (uint i = 0; i < length; i++) {
            CauldronInfo memory info = registry.get(i);
            if (info.version < 4) continue;

            ICauldronV4 cauldron = ICauldronV4(info.cauldron);
            cauldronOwner.setBlacklistedCallee(cauldron, address(0), false);
        }

        // revoke ROLE_SET_BLACKLISTED_CALLEE permission
        pushPrank(cauldronOwner.owner());
        cauldronOwner.revokeRoles(alice, cauldronOwner.ROLE_SET_BLACKLISTED_CALLEE());
        popPrank();

        pushPrank(alice);
        for (uint i = 0; i < length; i++) {
            CauldronInfo memory info = registry.get(i);
            if (info.version < 4) continue;

            ICauldronV4 cauldron = ICauldronV4(info.cauldron);
            vm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
            cauldronOwner.setBlacklistedCallee(cauldron, address(0), false);
        }

        // grant ROLE_OPERATOR permission
        pushPrank(cauldronOwner.owner());
        cauldronOwner.grantRoles(alice, cauldronOwner.ROLE_OPERATOR());
        popPrank();

        for (uint i = 0; i < length; i++) {
            CauldronInfo memory info = registry.get(i);
            if (info.version < 4) continue;

            ICauldronV4 cauldron = ICauldronV4(info.cauldron);
            cauldronOwner.setBlacklistedCallee(cauldron, address(0), false);
        }
    }

    function testSetFeeTo() public {
        CauldronRegistry registry = CauldronRegistry(toolkit.getAddress(ChainId.All, "cauldronRegistry"));
        uint length = registry.length();

        pushPrank(alice);
        for (uint i = 0; i < length; i++) {
            CauldronInfo memory info = registry.get(i);
            ICauldronV2 cauldron = ICauldronV2(info.cauldron);

            vm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
            cauldronOwner.setFeeTo(cauldron, address(0));
        }

        pushPrank(cauldronOwner.owner());
        for (uint i = 0; i < length; i++) {
            CauldronInfo memory info = registry.get(i);
            ICauldronV2 cauldron = ICauldronV2(info.cauldron);
            address mc = address(ICauldronV2(info.cauldron).masterContract());

            if (mc != address(cauldron)) {
                vm.expectRevert(abi.encodeWithSignature("ErrNotMasterContract(address)", cauldron));
                cauldronOwner.setFeeTo(cauldron, address(0));
            } else {
                cauldronOwner.setFeeTo(cauldron, address(0));
                assertEq(cauldron.feeTo(), address(0));
            }
        }
        popPrank();
    }

    function testSetTreasury() public {
        pushPrank(cauldronOwner.owner());
        cauldronOwner.setTreasury(address(0x0));
        assertEq(cauldronOwner.treasury(), address(0x0));
        popPrank();
    }

    function testSetRegistry() public {
        CauldronRegistry registry = CauldronRegistry(toolkit.getAddress(ChainId.All, "cauldronRegistry"));

        pushPrank(cauldronOwner.owner());
        cauldronOwner.setRegistry(registry);
        assertEq(address(cauldronOwner.registry()), address(registry));
        popPrank();
    }

    function testTransferMasterContractOwnership() public {
        CauldronRegistry registry = CauldronRegistry(toolkit.getAddress(ChainId.All, "cauldronRegistry"));
        uint length = registry.length();

        pushPrank(alice);
        for (uint i = 0; i < length; i++) {
            CauldronInfo memory info = registry.get(i);
            address mc = address(ICauldronV2(info.cauldron).masterContract());

            vm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
            cauldronOwner.transferMasterContractOwnership(mc, address(0));
        }
        popPrank();

        pushPrank(cauldronOwner.owner());
        for (uint i = 0; i < length; i++) {
            CauldronInfo memory info = registry.get(i);
            address mc = address(ICauldronV2(info.cauldron).masterContract());

            if (Owned(mc).owner() == address(cauldronOwner)) {
                cauldronOwner.transferMasterContractOwnership(mc, bob);
                assertEq(Owned(mc).owner(), bob);
            }
        }
        popPrank();

        for (uint i = 0; i < length; i++) {
            CauldronInfo memory info = registry.get(i);
            address mc = address(ICauldronV2(info.cauldron).masterContract());
            assertEq(Owned(mc).owner(), bob);
        }
    }

    function _changeCauldronOwners() private {
        CauldronRegistry registry = CauldronRegistry(toolkit.getAddress(ChainId.All, "cauldronRegistry"));
        uint length = registry.length();

        for (uint i = 0; i < length; i++) {
            CauldronInfo memory info = registry.get(i);
            address mc = address(ICauldronV2(info.cauldron).masterContract());
            address owner = Owned(mc).owner();

            if (owner != address(cauldronOwner)) {
                pushPrank(owner);
                try Owned(mc).transferOwnership(address(cauldronOwner)) {} catch {
                    try BoringOwnable(mc).transferOwnership(address(cauldronOwner), true, false) {} catch {}
                }
                popPrank();

                if (Owned(mc).owner() != address(cauldronOwner)) {
                    revert("transferOwnership failed");
                }
            }
        }
    }
}
