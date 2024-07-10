// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";

contract ToolkitTest is BaseTest {
    function setUp() public override {}

    function testGetAddress() public {
        fork(ChainId.Kava, Block.Latest);
        assertEq(block.chainid, ChainId.Kava);
        assertEq(toolkit.getAddress("safe.rewards"), 0x11E7e9cE260b28D7E7639Fc3f6C57F85599e1e66); // search path: kava.json first, then all.json
        assertEq(toolkit.getAddress(block.chainid, "safe.rewards"), 0x11E7e9cE260b28D7E7639Fc3f6C57F85599e1e66); // explicit chain, kava.json

        vm.expectRevert();
        toolkit.getAddress(ChainId.Arbitrum, "safe.rewards"); // doesn't exist

        vm.expectRevert();
        toolkit.getAddress("arbitrum.safe.rewards"); // doesn't exist

        assertEq(toolkit.getAddress("kava.safe.rewards"), 0x11E7e9cE260b28D7E7639Fc3f6C57F85599e1e66);

        fork(ChainId.Arbitrum, 230821723);
        assertEq(block.chainid, ChainId.Arbitrum);
        assertEq(toolkit.getAddress("safe.rewards"), 0x485008d95b1AdE24269ceF97C4Cd589D421bb20D);

        vm.expectRevert();
        toolkit.getAddress(ChainId.Arbitrum, "safe.rewards"); // doesn't exist

        assertEq(toolkit.getAddress(ChainId.Kava, "safe.rewards"), 0x11E7e9cE260b28D7E7639Fc3f6C57F85599e1e66);

        vm.expectRevert();
        toolkit.getAddress("arbitrum.safe.rewards"); // doesn't exist

        assertEq(toolkit.getAddress("kava.safe.rewards"), 0x11E7e9cE260b28D7E7639Fc3f6C57F85599e1e66);
        assertEq(toolkit.getAddress("marketLens"), 0x1E217d3cA2a19f2cB0F9f12a65b40f335286758E);
    }
}
