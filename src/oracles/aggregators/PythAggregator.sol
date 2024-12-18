// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IAggregator} from "/interfaces/IAggregator.sol";
import {IPyth} from "/interfaces/IPyth.sol";

contract PythAggregator is IAggregator {
    error InvalidDecimals();
    error NegativePriceFeed();

    IPyth public immutable pyth;
    bytes32 public immutable feedId;
    uint256 public immutable maxAge;

    uint8 private immutable _decimals;

    constructor(IPyth _pyth, bytes32 _feedId, uint256 _maxAge) {
        pyth = _pyth;
        feedId = _feedId;
        maxAge = _maxAge;

        IPyth.PriceInfo memory priceInfo = _pyth.getPriceUnsafe(_feedId);

        if (priceInfo.expo > 0) {
            revert InvalidDecimals();
        }

        _decimals = uint8(uint32(-priceInfo.expo));
    }

    function decimals() external view override returns (uint8) {
        return _decimals;
    }

    function latestAnswer() public view returns (int256 _price) {
        IPyth.PriceInfo memory priceInfo = pyth.getPriceNoOlderThan(feedId, maxAge);

        if (priceInfo.price < 0) {
            revert NegativePriceFeed();
        }

        return priceInfo.price;
    }

    function latestRoundData() public view returns (uint80, int256 answer, uint256, uint256 updatedAt, uint80) {
        return (0, latestAnswer(), 0, 0, 0);
    }
}
