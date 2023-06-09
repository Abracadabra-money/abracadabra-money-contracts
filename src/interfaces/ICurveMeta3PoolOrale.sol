// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "interfaces/IOracle.sol";

interface ICurveMeta3PoolOrale is IOracle {
    function curvePool() external view returns (address);
}
