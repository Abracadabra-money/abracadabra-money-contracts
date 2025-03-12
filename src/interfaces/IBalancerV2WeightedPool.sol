// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

interface IBalancerV2WeightedPool is IERC20 {
    function getPoolId() external view returns (bytes32);

    function getNormalizedWeights() external view returns (uint256[] memory);

    function getInvariant() external view returns (uint256);

    function getActualSupply() external view returns (uint256);
}
