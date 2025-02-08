// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {IAggregator} from "/interfaces/IAggregator.sol";
import {BabylonianLib} from "/libraries/BabylonianLib.sol";
import {IKodiakVaultV1} from "/interfaces/IKodiak.sol";

/// @title KodiakIslandLPAggregator
/// @author Berastotle
/// @notice Aggregator used for getting the price of an LP token denominated in USD.
/// @dev Extend Uniswap V2 solution based on here https://blog.alphafinance.io/fair-lp-token-pricing/ to Kodiak UniV3 ALM
contract KodiakIslandAggregator is IAggregator {
    uint256 public constant WAD = 18;

    error ErrInvalidDecimals();
    error ErrPriceCastOverflow();
    error ErrInvalidValue();
    error ErrInvalidSupply();
    error ErrValueOverflow();

    IKodiakVaultV1 public immutable island;
    IAggregator immutable aggregator0;
    uint8 immutable decimals0;
    uint256 immutable tokenDecimalScale0;
    uint256 immutable aggregatorDecimalScale0;
    IAggregator immutable aggregator1;
    uint8 immutable decimals1;
    uint256 immutable tokenDecimalScale1;
    uint256 immutable aggregatorDecimalScale1;

    uint8 public immutable override decimals;

    constructor(IKodiakVaultV1 island_, IAggregator tokenAggregator0, IAggregator tokenAggregator1) {
        island = island_;
        uint8 decimal;

        // Token0
        decimal = IERC20Metadata(island_.token0()).decimals();
        aggregator0 = tokenAggregator0;
        decimals0 = decimal;
        tokenDecimalScale0 = (10 ** (WAD - decimal));
        aggregatorDecimalScale0 = 10 ** (WAD - tokenAggregator0.decimals());

        // Token1
        decimal = IERC20Metadata(island_.token1()).decimals();
        aggregator1 = tokenAggregator1;
        decimals1 = decimal;
        tokenDecimalScale1 = (10 ** (WAD - decimal));
        aggregatorDecimalScale1 = 10 ** (WAD - tokenAggregator1.decimals());

        decimals = IERC20Metadata(address(island)).decimals();

        require(decimals == WAD, ErrInvalidDecimals());
    }

    function latestAnswer() public view override returns (int256) {
        (, int256 feed0, , , ) = aggregator0.latestRoundData();
        (, int256 feed1, , , ) = aggregator1.latestRoundData();

        uint256 normalizedPriceFeed0 = uint256(feed0) * aggregatorDecimalScale0;
        uint256 normalizedPriceFeed1 = uint256(feed1) * aggregatorDecimalScale1;
        uint160 priceSqrtRatioX96 = _getSqrtPriceX96(normalizedPriceFeed0, normalizedPriceFeed1);
        (uint256 reserve0, uint256 reserve1) = island.getUnderlyingBalancesAtPrice(priceSqrtRatioX96);

        uint256 normalizedReserve0 = reserve0 * tokenDecimalScale0;
        uint256 normalizedReserve1 = reserve1 * tokenDecimalScale1;
        uint256 totalSupply = island.totalSupply();
        uint256 totalValue = (normalizedReserve0 * normalizedPriceFeed0) + (normalizedReserve1 * normalizedPriceFeed1);

        require(totalValue > 0, ErrInvalidValue());
        require(totalSupply > 0, ErrInvalidSupply());

        uint256 result = totalValue / totalSupply;
        require(result <= uint256(type(int256).max), ErrValueOverflow());

        return int256(result);
    }

    function _getSqrtPriceX96(uint256 normalizedPriceFeed0, uint256 normalizedPriceFeed1) internal pure returns (uint160) {
        uint256 sqrtPrice = (BabylonianLib.sqrt((normalizedPriceFeed0 * 1e18) / normalizedPriceFeed1) * 2 ** 96) / 1e9;
        require(sqrtPrice <= type(uint160).max, ErrPriceCastOverflow());

        return uint160(sqrtPrice);
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (0, latestAnswer(), 0, 0, 0);
    }
}
