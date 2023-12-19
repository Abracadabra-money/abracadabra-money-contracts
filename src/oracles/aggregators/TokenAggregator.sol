// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IAggregator} from "interfaces/IAggregator.sol";

/// @title TokenAggregator
/// @notice Aggregator used for getting the price of 1 token in given denominator using Chainlink
contract TokenAggregator is IAggregator {
    error NegativePriceFeed();

    IAggregator public immutable tokenUSD;
    IAggregator public immutable denominatorUSD;

    uint8 public immutable oracle0Decimals;
    uint8 public immutable oracle1Decimals;

    uint8 public immutable _decimals;

    constructor(IAggregator _tokenUSD, IAggregator _denominatorUSD, uint8 __decimals) {
        tokenUSD = _tokenUSD;
        denominatorUSD = _denominatorUSD;

        oracle0Decimals = _tokenUSD.decimals();
        oracle1Decimals = _denominatorUSD.decimals();

        _decimals = __decimals;
    }

    function decimals() external view override returns (uint8) {
        return _decimals;
    }

    function latestAnswer() public view override returns (int256 answer) {
        int256 tokenUSDFeed = tokenUSD.latestAnswer();
        int256 denominatorUSDFeed = denominatorUSD.latestAnswer();

        if (tokenUSDFeed < 0 || denominatorUSDFeed < 0) {
            revert NegativePriceFeed();
        }

        uint256 normalizedTokenUSDFeed = uint256(tokenUSDFeed) * (10 ** (_decimals - oracle0Decimals));
        uint256 normalizedDenominatorUSDFeed = uint256(denominatorUSDFeed) * (10 ** (_decimals - oracle1Decimals));

        return int256((normalizedTokenUSDFeed * (10**_decimals)) / normalizedDenominatorUSDFeed);
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (0, latestAnswer(), 0, 0, 0);
    }
}
