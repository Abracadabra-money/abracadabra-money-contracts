// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/MagicUSD0pp.s.sol";
import {ExchangeRouterMock} from "./mocks/ExchangeRouterMock.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract MagicUSD0ppTest is BaseTest {
    address constant USD0PP_TOKEN = 0x35D8949372D46B7a3D5A56006AE77B215fc69bC0;
    address constant USUAL_TOKEN = 0xC4441c2BE5d8fA8126822B9929CA0b81Ea0DE38E;
    MagicUSD0pp implementationV2;
    MagicUSD0ppHarvester harvester;
    ExchangeRouterMock routerMock;

    MagicUSD0pp instance;

    function _setUpV1() internal {
        fork(ChainId.Mainnet, 20866907);
        super.setUp();

        MagicUSD0ppScript script = new MagicUSD0ppScript();
        script.setTesting(true);

        (instance, implementationV2, harvester) = script.deploy();

        assertNotEq(instance.owner(), address(0), "owner should be the deployer");
    }

    function _setUpV2() internal {
        fork(ChainId.Mainnet, 21440416);
        super.setUp();

        MagicUSD0ppScript script = new MagicUSD0ppScript();
        script.setTesting(true);

        (instance, implementationV2, harvester) = script.deploy();
    }

    function testUpgrade() public {
        _setUpV1();

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

    function testUpgradeV2() public {
        _setUpV2();

        address owner = instance.owner();
        pushPrank(owner);
        instance.upgradeToAndCall(address(implementationV2), "");
        assertEq(instance.owner(), owner, "Owner should be the same");
        popPrank();
    }

    function testHarvestV2() public {
        _setUpV2();

        routerMock = new ExchangeRouterMock(USUAL_TOKEN, USD0PP_TOKEN);
        deal(USUAL_TOKEN, address(routerMock), 2000 ether);
        deal(USD0PP_TOKEN, address(routerMock), 1000 ether);

        address owner = instance.owner();
        pushPrank(owner);
        instance.upgradeToAndCall(address(implementationV2), "");
        instance.setOperator(address(harvester), true);
        harvester.setAllowedRouter(address(routerMock), true); // whitelist mock router
        popPrank();

        deal(USUAL_TOKEN, address(harvester), 1000 ether); // simulate USUAL merkle claim

        uint256 vaultTotalAssetBefore = instance.totalAssets();

        pushPrank(toolkit.getAddress("safe.devOps.gelatoProxy"));
        harvester.run(address(routerMock), abi.encodeCall(routerMock.swap, (address(harvester))), 0);
        popPrank();

        assertEq(IERC20(USD0PP_TOKEN).balanceOf(address(harvester)), 0, "Harvester should have 0 USD0PP");

        // remove %5 fee
        assertEq(instance.totalAssets(), vaultTotalAssetBefore + 1000 ether - 50 ether, "Vault should have 950 USD0PP more");
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
