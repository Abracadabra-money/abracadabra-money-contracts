// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "src/Contract.sol";
import "utils/BaseTest.sol";
import "script/Contract.s.sol";
import "src/DegenBox.sol";

contract ContractTest is BaseTest {
    Contract public c;
    DegenBox public d;

    function setUp() public override {
        super.setUp();

        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 15219128);
        ContractScript script = new ContractScript();
        script.setTesting(true);
        (c, d) = script.run();
    }

    function testExample() public {
        vm.startPrank(c.owner());
        c.setOwner(0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045);
        vm.stopPrank();
        assertEq(alice.balance, 100 ether);
        assertTrue(c.owner() != constants.getAddress("xMerlin"));
        assertTrue(d.owner() != constants.getAddress("xMerlin"));
        assertEq(c.mim(), 0x99D8a9C45b2ecA8864373A26D1459e3Dff1e17F3);
    }
}
