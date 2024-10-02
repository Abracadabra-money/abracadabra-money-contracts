// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/MagicUSD0pp.s.sol";

contract MagicUSD0ppTest is BaseTest {
    MagicUSD0pp instance;

    function setUp() public override {
        fork(ChainId.Mainnet, 20866907);
        super.setUp();

        MagicUSD0ppScript script = new MagicUSD0ppScript();
        script.setTesting(true);

        (instance) = script.deploy();

        assertNotEq(instance.owner(), address(0), "owner should be the deployer");
    }

    function testUpgrade() public {
        address currentOwner = instance.owner();
        
        address randomAddress = makeAddr("random");
        MagicUSD0ppV2 newImpl = new MagicUSD0ppV2(randomAddress);

        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        newImpl.initialize(randomAddress);

        pushPrank(alice);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
        instance.upgradeToAndCall(address(newImpl), "");
        popPrank();

        address owner = instance.owner();
        pushPrank(owner);
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        instance.upgradeToAndCall(address(newImpl), abi.encodeCall(newImpl.failingInitialize, ()));

        instance.upgradeToAndCall(address(newImpl), abi.encodeCall(newImpl.initializeV2, (randomAddress)));
        assertEq(instance.owner(), owner, "Owner should be the same");
        assertEq(MagicUSD0ppV2(address(instance)).someNewVariable(), randomAddress, "New variable should be set");
        popPrank();

        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        MagicUSD0ppV2(address(instance)).initializeV2(alice);
        MagicUSD0ppV2(address(instance)).someFunction(tx.origin);

        assertEq(instance.owner(), currentOwner, "Owner should be the same");
    }
}

// New contract for testing upgrade
contract MagicUSD0ppV2 is MagicUSD0pp {
    address public someNewVariable;

    constructor(address _someNewVariable) MagicUSD0pp(_someNewVariable) {
        someNewVariable = _someNewVariable;
    }

    function initializeV2(address _someNewVariable) public reinitializer(2) {
        someNewVariable = _someNewVariable;
    }

    function failingInitialize() public pure {
        revert InvalidInitialization();
    }

    function someFunction(address _owner) public {
        someNewVariable = _owner;
    }
}
