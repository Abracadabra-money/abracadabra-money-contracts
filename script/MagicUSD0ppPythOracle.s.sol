// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {ProxyOracle} from "src/oracles/ProxyOracle.sol";
import {IOracle} from "src/interfaces/IOracle.sol";

contract MagicUSD0ppChainlinkOracleScript is BaseScript {
    bytes32 constant USD0PP_FEED_ID = 0xf9c96a45784d0ce4390825a43a313149da787e6a6c66076f3a3f83e92501baeb;
    uint256 public constant MAX_AGE = 45;

    function deploy() public {
        address pyth = toolkit.getAddress("pyth");
        address magicUSD0pp = 0x73075fD1522893D9dC922991542f98F08F2c1C99;

        vm.startBroadcast();
        address aggregator = deploy("USD0ppPythAggregator", "PythAggregator.sol:PythAggregator", abi.encode(pyth, USD0PP_FEED_ID, MAX_AGE));

        deploy("MagicUSD0pp_Oracle", "ERC4626Oracle.sol:ERC4626Oracle", abi.encode("MagicUSD0++/USD", magicUSD0pp, aggregator));

        /// @dev Schedule this change on the multisig
        //if (oracle.oracleImplementation() != impl) {
        //    oracle.changeOracleImplementation(impl);
        //}

        vm.stopBroadcast();
    }
}
