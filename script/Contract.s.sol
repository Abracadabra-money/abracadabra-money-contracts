// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "src/Contract.sol";

contract ContractScript is Script {
    function setUp() public {}

    function run() public returns (Contract) {
        vm.startBroadcast();

        Contract c = new Contract();

        vm.stopBroadcast();

        return (c);
    }
}
