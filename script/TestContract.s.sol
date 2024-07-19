// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";

contract TestContractScript is BaseScript {
    function deploy() public {
        vm.startBroadcast();
        deploy("TestContract", "TestContract.sol:TestContract", abi.encode(tx.origin));
        vm.stopBroadcast();
    }
}