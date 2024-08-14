// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";

contract ToolkitTest is BaseTest {
    function setUp() public override {}

    function testGetAddress() public {
        toolkit.setAddress(0, "my_address", 0x485008d95b1AdE24269ceF97C4Cd589D421bb20D);
        toolkit.setAddress(0, "my_address2", 0x1E217d3cA2a19f2cB0F9f12a65b40f335286758E);
        toolkit.setAddress(ChainId.Mainnet, "my_address", 0x11E7e9cE260b28D7E7639Fc3f6C57F85599e1e66);

        vm.chainId(ChainId.Mainnet);
        assertEq(toolkit.getAddress("my_address"), 0x11E7e9cE260b28D7E7639Fc3f6C57F85599e1e66); // search path: mainnet first, then all
        assertEq(toolkit.getAddress(block.chainid, "my_address"), 0x11E7e9cE260b28D7E7639Fc3f6C57F85599e1e66); // explicit chain, kava

        vm.expectRevert();
        toolkit.getAddress(ChainId.Arbitrum, "my_address"); // doesn't exist

        vm.expectRevert();
        toolkit.getAddress("arbitrum.my_address"); // doesn't exist

        assertEq(toolkit.getAddress("mainnet.my_address"), 0x11E7e9cE260b28D7E7639Fc3f6C57F85599e1e66);

        vm.chainId(ChainId.Arbitrum);
        assertEq(toolkit.getAddress("my_address"), 0x485008d95b1AdE24269ceF97C4Cd589D421bb20D);

        vm.expectRevert();
        toolkit.getAddress(ChainId.Arbitrum, "my_address"); // doesn't exist

        assertEq(toolkit.getAddress(ChainId.Mainnet, "my_address"), 0x11E7e9cE260b28D7E7639Fc3f6C57F85599e1e66);

        vm.expectRevert();
        toolkit.getAddress("arbitrum.my_address"); // doesn't exist

        assertEq(toolkit.getAddress("mainnet.my_address"), 0x11E7e9cE260b28D7E7639Fc3f6C57F85599e1e66);
        assertEq(toolkit.getAddress("my_address2"), 0x1E217d3cA2a19f2cB0F9f12a65b40f335286758E);
    }
}
