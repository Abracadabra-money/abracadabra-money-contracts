// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseTest.sol";
import {OwnableOperators} from "/mixins/OwnableOperators.sol";

// Mock contract to test onlyOperators modifier with owner initialization
contract MockContractWithOperators is OwnableOperators {
    function initialize(address _owner) public {
        _initializeOwner(_owner);
    }

    function onlyOperatorsFunction() external onlyOperators {}

    function onlyOwnerFunction() external onlyOwner {}
}

contract mockWithOperatorsTest is BaseTest {
    address owner;
    address operator1;
    address operator2;
    MockContractWithOperators mockWithOperators;

    function setUp() public override {
        owner = makeAddr("Owner");
        operator1 = makeAddr("Operator1");
        operator2 = makeAddr("Operator2");

        mockWithOperators = new MockContractWithOperators();
        assertEq(mockWithOperators.owner(), address(0));

        mockWithOperators.initialize(owner);
    }

    function testSetOperator() public {
        pushPrank(owner);
        mockWithOperators.onlyOperatorsFunction();
        mockWithOperators.onlyOwnerFunction();
        popPrank();

        pushPrank(operator1);
        vm.expectRevert(OwnableOperators.Unauthorized.selector);
        mockWithOperators.onlyOperatorsFunction();
        vm.expectRevert(OwnableOperators.Unauthorized.selector);
        mockWithOperators.onlyOwnerFunction();
        popPrank();

        pushPrank(owner);
        mockWithOperators.setOperator(operator1, true);
        assertTrue(mockWithOperators.operators(operator1));
        mockWithOperators.onlyOwnerFunction();
        popPrank();

        pushPrank(operator1);
        mockWithOperators.onlyOperatorsFunction();
        vm.expectRevert(OwnableOperators.Unauthorized.selector);
        mockWithOperators.onlyOwnerFunction();
        popPrank();

        pushPrank(owner);
        mockWithOperators.setOperator(operator1, false);
        assertFalse(mockWithOperators.operators(operator1));
        mockWithOperators.onlyOwnerFunction();
        popPrank();

        pushPrank(operator1);
        vm.expectRevert(OwnableOperators.Unauthorized.selector);
        mockWithOperators.onlyOperatorsFunction();
        vm.expectRevert(OwnableOperators.Unauthorized.selector);
        mockWithOperators.onlyOwnerFunction();
        popPrank();
    }

    function testTransferOwnership() public {
        address newOwner = makeAddr("NewOwner");

        pushPrank(owner);
        mockWithOperators.transferOwnership(newOwner);
        assertEq(mockWithOperators.owner(), newOwner);
        popPrank();

        pushPrank(newOwner);
        mockWithOperators.transferOwnership(owner);
        assertEq(mockWithOperators.owner(), owner);
        popPrank();
    }

    function testOnlyOwnerCanSetOperator() public {
        pushPrank(operator1);
        vm.expectRevert(OwnableOperators.Unauthorized.selector);
        mockWithOperators.setOperator(operator2, true);
        popPrank();
    }

    function testUninitializedOwnerCannotCallSetOperator() public {
        mockWithOperators = new MockContractWithOperators();

        pushPrank(owner);
        vm.expectRevert(OwnableOperators.Unauthorized.selector);
        mockWithOperators.setOperator(operator1, true);
        mockWithOperators.initialize(owner);
        mockWithOperators.setOperator(operator1, true);
        popPrank();
    }

    function testSetMultipleOperators() public {
        pushPrank(owner);
        mockWithOperators.setOperator(operator1, true);
        mockWithOperators.setOperator(operator2, true);
        assertTrue(mockWithOperators.operators(operator1));
        assertTrue(mockWithOperators.operators(operator2));
        popPrank();

        pushPrank(operator1);
        mockWithOperators.onlyOperatorsFunction();
        vm.expectRevert(OwnableOperators.Unauthorized.selector);
        mockWithOperators.onlyOwnerFunction();
        popPrank();

        pushPrank(operator2);
        mockWithOperators.onlyOperatorsFunction();
        vm.expectRevert(OwnableOperators.Unauthorized.selector);
        mockWithOperators.onlyOwnerFunction();
        popPrank();

        pushPrank(owner);
        mockWithOperators.setOperator(operator1, false);
        popPrank();

        pushPrank(operator1);
        assertFalse(mockWithOperators.operators(operator1));
        vm.expectRevert(OwnableOperators.Unauthorized.selector);
        mockWithOperators.onlyOperatorsFunction();
        vm.expectRevert(OwnableOperators.Unauthorized.selector);
        mockWithOperators.onlyOwnerFunction();
        popPrank();

        pushPrank(owner);
        mockWithOperators.setOperator(operator2, false);
        popPrank();

        pushPrank(operator2);
        assertFalse(mockWithOperators.operators(operator2));
        vm.expectRevert(OwnableOperators.Unauthorized.selector);
        mockWithOperators.onlyOperatorsFunction();
        vm.expectRevert(OwnableOperators.Unauthorized.selector);
        mockWithOperators.onlyOwnerFunction();
        popPrank();
    }
}
