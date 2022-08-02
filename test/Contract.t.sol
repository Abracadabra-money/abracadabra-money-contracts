// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "src/Contract.sol";
import "script/Contract.s.sol";

contract ContractTest is Test {
    Contract public c;

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 15219128);

        console.log(block.number);
        ContractScript script = new ContractScript();
        (c) = script.run();
    }

    function testExample() public {
        console.log("owner is", c.owner());
        assertTrue(true);
    }
}
