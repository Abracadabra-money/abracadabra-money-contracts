// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {IUniswapV2Pair} from "interfaces/IUniswapV2.sol";
import {IAggregator} from "interfaces/IAggregator.sol";
import {BabylonianLib} from "libraries/BabylonianLib.sol";
import {BoringERC20} from "BoringSolidity/libraries/BoringERC20.sol";

/// @title UniswapLikeLPAggregator
/// @author BoringCrypto, 0xCalibur
/// @notice Aggregator used for getting the price of an LP token denominated in tokenOracle.
/// @dev Optimized version based on https://blog.alphafinance.io/fair-lp-token-pricing/
contract UniswapLikeLPAggregator is IAggregator {
    using BoringERC20 for IERC20;

    IUniswapV2Pair public immutable pair;
    IAggregator public immutable tokenOracle;
    uint8 public immutable token0Decimals;
    uint8 public immutable token1Decimals;
    uint8 public immutable oracleDecimals;

    uint256 public constant WAD = 18;

    /// @param pair_ The UniswapV2 compatible pair address
    /// @param tokenOracle_ The token price 1 lp should be denominated with.
    constructor(IUniswapV2Pair pair_, IAggregator tokenOracle_) {
        pair = pair_;
        tokenOracle = tokenOracle_;

        token0Decimals = IERC20(pair_.token0()).safeDecimals();
        token1Decimals = IERC20(pair_.token1()).safeDecimals();

        oracleDecimals = tokenOracle_.decimals();
    }

    function decimals() external pure override returns (uint8) {
        return 18;
    }

    /// Calculates the lastest exchange rate
    /// @return the price of 1 lp in token price
    /// Example:
    /// - For 1 AVAX = $82
    /// - Total LP Value is: $160,000,000
    /// - LP supply is 8.25
    /// - latestAnswer() returns 234420638348190662349201 / 1e18 = 234420.63 AVAX
    /// - 1 LP = 234420.63 AVAX => 234420.63 * 8.25 * 82 = ≈$160,000,000
    function latestAnswer() public view override returns (int256) {
        (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(pair).getReserves();
        uint256 totalSupply = pair.totalSupply();

        uint256 normalizedReserve0 = reserve0 * (10 ** (WAD - token0Decimals));
        uint256 normalizedReserve1 = reserve1 * (10 ** (WAD - token1Decimals));

        uint256 k = normalizedReserve0 * normalizedReserve1;
        (, int256 priceFeed, , , ) = tokenOracle.latestRoundData();

        uint256 normalizedPriceFeed = uint256(priceFeed) * (10 ** (WAD - oracleDecimals));

        uint256 totalValue = uint256(BabylonianLib.sqrt((k / 1e18) * normalizedPriceFeed)) * 2;
        return int256((totalValue * 1e18) / totalSupply);
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (0, latestAnswer(), 0, 0, 0);
    }
}
