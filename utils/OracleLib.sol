// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "BoringSolidity/interfaces/IERC20.sol";
import "oracles/ProxyOracle.sol";
import "oracles/TokenOracle.sol";
import "oracles/InverseOracle.sol";

library OracleLib {
    function deploySimpleInvertedOracle(
        string memory desc,
        IAggregator aggregaor
    ) internal returns (ProxyOracle proxy) {
        proxy = new ProxyOracle();
        InverseOracle invertedOracle = new InverseOracle(aggregaor, IAggregator(address(0)), desc);
        proxy.changeOracleImplementation(invertedOracle);
    }
}
