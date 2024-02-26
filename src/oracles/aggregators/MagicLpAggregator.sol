// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {IERC20Metadata} from "openzeppelin-contracts/interfaces/IERC20Metadata.sol";
import {IAggregator} from "interfaces/IAggregator.sol";
import {IMagicLP} from "/mimswap/interfaces/IMagicLP.sol";
import "forge-std/console2.sol";

contract MagicLpAggregator is IAggregator {
    IMagicLP public immutable pair;
    IAggregator public immutable tokenOracle;
    uint8 public immutable quoteDecimals;
    uint8 public immutable oracleDecimals;

    uint256 public constant WAD = 18;

    /// @param pair_ The MagicLP pair address
    /// @param tokenOracle_ The token price 1 lp should be denominated with.
    constructor(IMagicLP pair_, IAggregator tokenOracle_) {
        pair = pair_;
        tokenOracle = tokenOracle_;
        quoteDecimals = IERC20Metadata(pair_._QUOTE_TOKEN_()).decimals();
        oracleDecimals = tokenOracle_.decimals();
    }

    function decimals() external pure override returns (uint8) {
        return 18;
    }

    function latestAnswer() public view override returns (int256) {
        uint256 normalizedMidPrice = pair.getMidPrice() * (10 ** (WAD - quoteDecimals));
        (, int256 priceFeed, , , ) = tokenOracle.latestRoundData();

        uint256 normalizedPriceFeed = uint256(priceFeed) * (10 ** (WAD - oracleDecimals));

        //console2.log("normalizedPriceFeed", normalizedPriceFeed);
        //console2.log("normalizedMidPrice", normalizedMidPrice);

        uint256 totalValue = uint256(FixedPointMathLib.sqrt(normalizedMidPrice * normalizedPriceFeed)) * 2;
        return int256(totalValue);
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (0, latestAnswer(), 0, 0, 0);
    }
}
