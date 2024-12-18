// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {ProxyOracle} from "src/oracles/ProxyOracle.sol";
import {IOracle} from "src/interfaces/IOracle.sol";

contract PenguOracleScript is BaseScript {
    bytes32 public constant PENGU_FEED_ID = 0xbed3097008b9b5e3c93bec20be79cb43986b85a996475589351a21e67bae9b61;
    uint256 public constant MAX_AGE = 45;
    uint8 public constant PENGU_DECIMALS = 18; // TBD

    function deploy() public returns (ProxyOracle oracle) {
        address pyth = toolkit.getAddress("pyth");

        vm.startBroadcast();
        address aggregator = deploy("PenguPythAggregator", "PythAggregator.sol:PythAggregator", abi.encode(pyth, PENGU_FEED_ID, MAX_AGE));

        oracle = ProxyOracle(deploy("Pengu_ProxyOracle", "ProxyOracle.sol:ProxyOracle"));
        IOracle impl = IOracle(
            deploy("Pengu_InverseERC20Oracle", "InverseOracle.sol:InverseOracle", abi.encode("Pengu/USD", aggregator, PENGU_DECIMALS))
        );

        if (oracle.oracleImplementation() != impl) {
            oracle.changeOracleImplementation(impl);
        }

        vm.stopBroadcast();

    
    }
}
