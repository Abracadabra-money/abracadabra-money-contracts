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

    function setUp() public override {
        fork(ChainId.Mainnet, 21440416);
        super.setUp();

        MagicUSD0ppScript script = new MagicUSD0ppScript();
        script.setTesting(true);

        (instance, implementationV2, harvester) = script.deploy();
    }

    function testUpgradeV2() public {
        address owner = instance.owner();
        pushPrank(owner);
        instance.upgradeToAndCall(address(implementationV2), "");
        assertEq(instance.owner(), owner, "Owner should be the same");
        popPrank();
    }

    function testHarvestV2() public {
        routerMock = new ExchangeRouterMock(USUAL_TOKEN, USD0PP_TOKEN);
        deal(USD0PP_TOKEN, address(routerMock), 1000 ether);
        assertEq(IERC20(USUAL_TOKEN).balanceOf(address(routerMock)), 0, "Router should have 0 USUAL");

        address owner = instance.owner();
        pushPrank(owner);
        instance.upgradeToAndCall(address(implementationV2), "");
        instance.setOperator(address(harvester), true);
        harvester.setAllowedRouter(address(routerMock), true); // whitelist mock router
        popPrank();

        deal(USUAL_TOKEN, address(instance), 2000 ether); // simulate USUAL merkle claim

        uint256 vaultTotalAssetBefore = instance.totalAssets();

        pushPrank(toolkit.getAddress("safe.devOps.gelatoProxy"));
        harvester.run(address(routerMock), abi.encodeCall(routerMock.swap, (address(harvester))), 0);
        popPrank();

        assertEq(IERC20(USUAL_TOKEN).balanceOf(address(routerMock)), 2000 ether, "Router should have 2000 USUAL");
        assertEq(IERC20(USD0PP_TOKEN).balanceOf(address(harvester)), 0, "Harvester should have 0 USD0PP");

        // remove %5 fee
        assertEq(instance.totalAssets(), vaultTotalAssetBefore + 1000 ether - 50 ether, "Vault should have 950 USD0PP more");
    }

    function testSetAllowedRouter() public {
        address randomRouter = makeAddr("router");

        // Test non-owner cannot set router
        pushPrank(alice);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
        harvester.setAllowedRouter(randomRouter, true);
        popPrank();

        // Test owner can set router
        address owner = instance.owner();
        pushPrank(owner);
        harvester.setAllowedRouter(randomRouter, true);
        popPrank();

        // Test router was properly whitelisted
        assertTrue(harvester.allowedRouters(randomRouter), "Router should be whitelisted");

        // Check allowances are properly set
        assertEq(IERC20(USUAL_TOKEN).allowance(address(harvester), randomRouter), type(uint256).max, "USUAL_TOKEN allowance should be max");

        // Test owner can remove router
        pushPrank(owner);
        harvester.setAllowedRouter(randomRouter, false);
        assertFalse(harvester.allowedRouters(randomRouter), "Router should be removed from whitelist");

        // Check allowances are properly revoked
        assertEq(IERC20(USUAL_TOKEN).allowance(address(harvester), randomRouter), 0, "USUAL_TOKEN allowance should be 0");
        popPrank();

        // check the event log change emit only when the router is changed
        pushPrank(owner);
        vm.recordLogs();
        harvester.setAllowedRouter(randomRouter, true);
        harvester.setAllowedRouter(randomRouter, true);
        popPrank();

        VmSafe.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries.length, 2, "Event should be emitted once");
        assertEq(entries[0].topics[0], keccak256("Approval(address,address,uint256)"), "Approval event should be emitted");
        assertEq(entries[1].topics[0], keccak256("LogAllowedRouterChanged(address,bool)"), "Event should be emitted");

        assertEq(IERC20(USUAL_TOKEN).allowance(address(harvester), randomRouter), type(uint256).max, "USUAL_TOKEN allowance should be max");
    }
}
