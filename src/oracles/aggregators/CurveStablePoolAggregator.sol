// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IAggregator} from "interfaces/IAggregator.sol";
import {ICurvePool} from "interfaces/ICurvePool.sol";
import {MathLib} from "libraries/MathLib.sol";

/// @title CurveStablePoolAggregator
/// @notice An aggregator that expect a CurvePool with stablecoins and uses
/// the one with the lowest price as the price of the pool along with the virtual price
contract CurveStablePoolAggregator is IAggregator {
    ICurvePool public immutable curvePool;
    uint256 public immutable decimalScale;
    IAggregator[] public aggregators;

    constructor(ICurvePool _curvePool, IAggregator[] memory _aggregators) {
        curvePool = _curvePool;
        aggregators = _aggregators;

        // assert that all aggregators are the same decimals
        uint8 aggregatorDecimals = _aggregators[0].decimals();
        for (uint256 i = 1; i < _aggregators.length; ) {
            assert(_aggregators[i].decimals() == aggregatorDecimals);
            unchecked {
                ++i;
            }
        }

        decimalScale = 10 ** aggregatorDecimals;
        assert(decimalScale != 0);
    }

    function decimals() external view returns (uint8) {
        return uint8(curvePool.decimals());
    }

    function latestAnswer() public view override returns (int256) {
        uint256 minStable = uint256(aggregators[0].latestAnswer());

        for (uint256 i = 1; i < aggregators.length - 1; ) {
            uint256 price = uint256(aggregators[i].latestAnswer());
            if (price < minStable) {
                minStable = price;
            }
            unchecked {
                ++i;
            }
        }

        return int256((curvePool.get_virtual_price() * minStable) / decimalScale);
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (0, latestAnswer(), 0, 0, 0);
    }
}
