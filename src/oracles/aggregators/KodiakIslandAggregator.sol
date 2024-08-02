// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {IAggregator} from "/interfaces/IAggregator.sol";
import {IKodiakIsland} from "/interfaces/IKodiakIsland.sol";
import {IAggregator} from "/interfaces/IAggregator.sol";
import {BabylonianLib} from "/libraries/BabylonianLib.sol";

/// @title KodiakIslandLPAggregator
/// @author Berastotle
/// @notice Aggregator used for getting the price of an LP token denominated in USD.
/// @dev Extend Uniswap V2 solution based on here https://blog.alphafinance.io/fair-lp-token-pricing/ to Kodiak UniV3 ALM
contract KodiakIslandAggregator is IAggregator {
    uint256 public constant WAD = 18;
    uint256 constant FIXED_POINT_96 = 2 ** 96;

    IKodiakIsland public immutable island;

    uint8 public immutable decimals0;
    uint256 public immutable priceFeedScale0;
    uint256 public immutable reserveScale0;
    IAggregator public immutable oracle0;

    uint8 public immutable decimals1;
    uint256 public immutable priceFeedScale1;
    uint256 public immutable reserveScale1;
    IAggregator public immutable oracle1;

    /// @param island_ The Kodiak ALM address
    /// @param tokenOracle0_ USD Oracle for token0
    /// @param tokenOracle1_ USD Oracle for token1
    constructor(IKodiakIsland island_, IAggregator tokenOracle0_, IAggregator tokenOracle1_) {
        island = island_;

        decimals0 = IERC20Metadata(island_.token0()).decimals();
        priceFeedScale0 = 10 ** (WAD - decimals0);
        reserveScale0 = 10 ** (WAD - decimals0);
        oracle0 = tokenOracle0_;

        decimals1 = IERC20Metadata(island_.token1()).decimals();
        priceFeedScale1 = 10 ** (WAD - tokenOracle1_.decimals());
        reserveScale1 = 10 ** (WAD - decimals1);
        oracle1 = tokenOracle1_;
    }

    function decimals() external pure override returns (uint8) {
        return 18;
    }

    /// Calculates the lastest exchange rate
    /// @return the price of 1 lp in USD
    function latestAnswer() public view override returns (int256) {
        //Assume these price feed return price in USD
        (, int256 priceFeed_token0, , , ) = oracle0.latestRoundData();
        (, int256 priceFeed_token1, , , ) = oracle1.latestRoundData();

        uint256 normalizedPriceFeedToken0 = uint256(priceFeed_token0) * priceFeedScale0;
        uint256 normalizedPriceFeedToken1 = uint256(priceFeed_token1) * priceFeedScale1;

        uint256 priceRatio = (normalizedPriceFeedToken0 * 1e18) / normalizedPriceFeedToken1;
        uint160 price_sqrtRatioX96 = uint160((BabylonianLib.sqrt(priceRatio) * FIXED_POINT_96) / 1e9); // Get current price in Uniswap math terms

        //Note: getUnderlyingBalancesAtPrice gets the reserves at a specified price based on UniV3 curve math + accumulated fees + token balances in contract
        //The token reserve math is as described here: https://docs.parallel.fi/parallel-finance/staking-and-derivative-token-yield-management/borrow-against-uniswap-v3-lp-tokens/uniswap-v3-lp-token-analyzer
        //As we use oracle price (rather than current bock pool balances) to get the reserves, this calculation isn't subject to flash loan exploit
        (uint256 reserve0, uint256 reserve1) = island.getUnderlyingBalancesAtPrice(price_sqrtRatioX96);

        uint256 normalizedReserve0 = reserve0 * reserveScale0;
        uint256 normalizedReserve1 = reserve1 * reserveScale1;
        uint256 totalValue = (normalizedReserve0 * normalizedPriceFeedToken0) + (normalizedReserve1 * normalizedPriceFeedToken1);

        return int256(totalValue / island.totalSupply());
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (0, latestAnswer(), 0, 0, 0);
    }
}
