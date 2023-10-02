// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/MagicGmVault.s.sol";

contract MagicGmVaultTest is BaseTest {
    MagicGmRouter router;
    IERC20 usdc;
    MagicGmRouterOrder orderImplementation;

    function setUp() public override {
        fork(ChainId.Arbitrum, 136644987);
        super.setUp();

        MagicGmVaultScript script = new MagicGmVaultScript();
        script.setTesting(true);

        router = script.deploy();
        orderImplementation = MagicGmRouterOrder(router.orderImplementation());
        usdc = IERC20(orderImplementation.tokenIn());
        deal(address(usdc), alice, 10_000e6);
    }

    function testInitialization() public {
        pushPrank(alice);
        usdc.approve(address(router), type(uint256).max);
        MagicGmRouterOrder order = MagicGmRouterOrder(router.createOrder{value: 1 ether}(10_000e6));

        vm.expectRevert();
        order.init(bob);
        assertEq(order.owner(), alice);

        assertNotEq(address(order), address(0));
        assertNotEq(address(order), address(router.orderImplementation()));

        assertNotEq(address(orderImplementation.USDC()), address(0));
        assertNotEq(address(orderImplementation.GM_BTC()), address(0));
        assertNotEq(address(orderImplementation.GM_ETH()), address(0));
        assertNotEq(address(orderImplementation.GM_ARB()), address(0));
        assertNotEq(address(orderImplementation.GMX_ROUTER()), address(0));
        assertNotEq(address(orderImplementation.DATASTORE()), address(0));
        assertNotEq(address(orderImplementation.DEPOSIT_VAULT()), address(0));
        assertNotEq(address(orderImplementation.SYNTHETICS_ROUTER()), address(0));

        assertEq(address(orderImplementation.USDC()), address(order.USDC()));
        assertEq(address(orderImplementation.GM_BTC()), address(order.GM_BTC()));
        assertEq(address(orderImplementation.GM_ETH()), address(order.GM_ETH()));
        assertEq(address(orderImplementation.GM_ARB()), address(order.GM_ARB()));
        assertEq(address(orderImplementation.GMX_ROUTER()), address(order.GMX_ROUTER()));
        assertEq(address(orderImplementation.DATASTORE()), address(order.DATASTORE()));
        assertEq(address(orderImplementation.DEPOSIT_VAULT()), address(order.DEPOSIT_VAULT()));
        assertEq(address(orderImplementation.SYNTHETICS_ROUTER()), address(order.SYNTHETICS_ROUTER()));

        popPrank();
    }

    function testOrder() public {
        pushPrank(alice);
        usdc.approve(address(router), type(uint256).max);
        MagicGmRouterOrder order = MagicGmRouterOrder(router.createOrder(10_000e6));
        
        popPrank();
    }
}
