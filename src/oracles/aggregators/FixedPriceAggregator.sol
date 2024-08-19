// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {IAggregator} from "/interfaces/IAggregator.sol";

contract FixedPriceAggregator is IAggregator {
    int256 public immutable latestAnswer;
    uint8 public immutable decimals;

    constructor(int256 _price, uint8 _decimals) {
        latestAnswer = _price;
        decimals = _decimals;
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (0, latestAnswer, 0, 0, 0);
    }
}
