// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {OwnableOperators} from "/mixins/OwnableOperators.sol";

contract MyContractScript is BaseScript {
    function deploy() public {
        vm.startBroadcast();
        OwnableOperators c = OwnableOperators(deploy("MyContract", "MyContract.sol:MyContract", abi.encode(tx.origin)));

        c.setOperator(address(tx.origin), true);
        vm.stopBroadcast();
    }
}