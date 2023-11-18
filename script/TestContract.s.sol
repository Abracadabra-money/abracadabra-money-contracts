// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import "/TestContract.sol";

contract TestContractScript is BaseScript {
    function deploy() public {
        vm.startBroadcast();
        deploy("TestContract", "TestContract.sol:TestContract", "");
        vm.stopBroadcast();
    }
}
