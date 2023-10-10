pragma solidity >=0.8.0;

import {GmxV2Market, GmxV2Price, GmxV2MarketPoolValueInfo} from "/libraries/GmxV2Libs.sol";

interface IGmxReader {
    function getMarket(address dataStore, address key) external view returns (GmxV2Market.Props memory);

    // @dev get the market token's price
    // @param dataStore DataStore
    // @param market the market to check
    // @param longTokenPrice the price of the long token
    // @param shortTokenPrice the price of the short token
    // @param indexTokenPrice the price of the index token
    // @param maximize whether to maximize or minimize the market token price
    // @return returns (the market token's price, MarketPoolValueInfo.Props)
    function getMarketTokenPrice(
        address dataStore,
        GmxV2Market.Props memory market,
        GmxV2Price.Props memory indexTokenPrice,
        GmxV2Price.Props memory longTokenPrice,
        GmxV2Price.Props memory shortTokenPrice,
        bytes32 pnlFactorType,
        bool maximize
    ) external view returns (int256, GmxV2MarketPoolValueInfo.Props memory);
}
