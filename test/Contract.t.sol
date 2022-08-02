// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/console.sol";
import "src/Contract.sol";
import "utils/BaseTest.sol";
import "script/Contract.s.sol";

contract ContractTest is BaseTest {
    Contract public c;

    function setUp() override public {
        super.setUp();

        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 15219128);

        console.log(block.number);
        ContractScript script = new ContractScript();
        script.setTesting(true);
        (c) = script.run();
    }

    function testExample() public {
        assertEq(c.owner(), deployer);
        assertEq(c.mim(), 0x99D8a9C45b2ecA8864373A26D1459e3Dff1e17F3);
    }
}
