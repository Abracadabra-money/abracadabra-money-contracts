// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {IAggregator} from "interfaces/IAggregator.sol";
import {BabylonianLib} from "libraries/BabylonianLib.sol";
import {BoringERC20} from "BoringSolidity/libraries/BoringERC20.sol";

interface IKdkIsland {
    function getUnderlyingBalancesAtPrice(uint160 sqrtRatioX96) external view returns (uint256 reserve0, uint256 reserve1);
    function totalSupply() external view returns (uint256);
    function token0() external view returns (address);
    function token1() external view returns (address);
}

/// @title KodiakIslandLPAggregator
/// @author Berastotle
/// @notice Aggregator used for getting the price of an LP token denominated in USD.
/// @dev Extend Uniswap V2 solution based on here https://blog.alphafinance.io/fair-lp-token-pricing/ to Kodiak UniV3 ALM
contract KodiakIslandAggregator {
    using BoringERC20 for IERC20;

    IKdkIsland public immutable island;
    IAggregator public immutable oracle_token0;
    IAggregator public immutable oracle_token1;
    uint8 public immutable decimals_token0;
    uint8 public immutable decimals_token1;
    uint8 public immutable oracleDecimals_token0;
    uint8 public immutable oracleDecimals_token1;

    uint256 public constant WAD = 18;

    /// @param island_ The Kodiak ALM address
    /// @param oracle_token0_ USD Oracle for token0
    /// @param oracle_token1_ USD Oracle for token1
    constructor(IKdkIsland island_, IAggregator oracle_token0_, IAggregator oracle_token1_) {
        island = island_;
        oracle_token0 = oracle_token0_;
        oracle_token1 = oracle_token1_;

        decimals_token0 = IERC20(island_.token0()).safeDecimals();
        decimals_token1 = IERC20(island_.token1()).safeDecimals();

        oracleDecimals_token0 = oracle_token0_.decimals();
        oracleDecimals_token1 = oracle_token1_.decimals();
    }

    function decimals() external pure override returns (uint8) {
        return 18;
    }

    /// Calculates the lastest exchange rate
    /// @return the price of 1 lp in USD
    function latestAnswer() public view override returns (int256) {

        //Assume these price feed return price in USD
        (, int256 priceFeed_token0, , , ) = oracle_token0.latestRoundData();
        (, int256 priceFeed_token1, , , ) = oracle_token1.latestRoundData();

        uint256 normalizedPriceFeed_token0 = uint256(priceFeed_token0) * (10 ** (WAD - oracleDecimals_token0));
        uint256 normalizedPriceFeed_token1 = uint256(priceFeed_token1) * (10 ** (WAD - oracleDecimals_token1));

        uint256 priceRatio = normalizedPriceFeed_token0 * 1e18 / normalizedPriceFeed_token1;
        uint160 price_sqrtRatioX96 = uint160((BabylonianLib.sqrt(priceRatio) * 2**96) / 1e9); //Get current price in Uniswap math terms

        //Note: getUnderlyingBalancesAtPrice gets the reserves at a specified price based on UniV3 curve math + accumulated fees + token balances in contract
        //The token reserve math is as described here: https://docs.parallel.fi/parallel-finance/staking-and-derivative-token-yield-management/borrow-against-uniswap-v3-lp-tokens/uniswap-v3-lp-token-analyzer
        //As we use oracle price (rather than current bock pool balances) to get the reserves, this calculation isn't subject to flash loan exploit
        (uint256 reserve0, uint256 reserve1) = island.getUnderlyingBalancesAtPrice(price_sqrtRatioX96);

        uint256 normalizedReserve0 = reserve0 * (10 ** (WAD - decimals_token0));
        uint256 normalizedReserve1 = reserve1 * (10 ** (WAD - decimals_token1));
        uint256 totalSupply = island.totalSupply();

        uint256 totalValue = normalizedReserve0 * normalizedPriceFeed_token0 + normalizedReserve1 * normalizedPriceFeed_token1;
        return int256((totalValue * 1e18) / totalSupply);
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (0, latestAnswer(), 0, 0, 0);
    }
}