// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {ProxyOracle} from "src/oracles/ProxyOracle.sol";
import {IOracle} from "src/interfaces/IOracle.sol";

contract MagicUSD0ppChainlinkOracleScript is BaseScript {
    function deploy() public {
        vm.startBroadcast();
        deploy("MagicUSD0pp_Oracle", "MagicUSD0ppOracle.sol:MagicUSD0ppOracle", "");

        /// @dev Schedule this change on the multisig
        //if (oracle.oracleImplementation() != impl) {
        //    oracle.changeOracleImplementation(impl);
        //}

        vm.stopBroadcast();
    }

    
}
