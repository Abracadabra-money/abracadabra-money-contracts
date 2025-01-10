// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {InverseOracle} from "/oracles/InverseOracle.sol";
import {IAggregator} from "/interfaces/IAggregator.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// @title UpperBoundedInverseOracle
/// @notice An oracle that inverts the price of an aggregator
contract UpperBoundedInverseOracle is InverseOracle {
    uint256 public immutable upperBoundary;

    /// @notice Construct an oracle that inverts the price of an aggregator
    /// @param _desc A description of the oracle
    /// @param _aggregator The aggregator to invert
    /// @param _upscaledTargetDecimals The number of decimals to return, 0 to use the aggregator's decimals
    /// @param _upperBoundary the upper boundary
    constructor(string memory _desc, IAggregator _aggregator, uint8 _upscaledTargetDecimals, uint256 _upperBoundary) InverseOracle(_desc,_aggregator, _upscaledTargetDecimals){
        upperBoundary = _upperBoundary;
   }

    function _get() internal virtual override view returns (uint256) {
        return decimalScale / Math.min(upperBoundary, uint256(aggregator.latestAnswer()));
    }
}
