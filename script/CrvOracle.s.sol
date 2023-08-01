// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "oracles/ProxyOracle.sol";
import "utils/CauldronDeployLib.sol";
import "oracles/CrvOracle.sol";

contract CrvOracleScript is BaseScript {
    function deploy() public {
        vm.startBroadcast();

        new CrvOracle();

        vm.stopBroadcast();
    }
}
