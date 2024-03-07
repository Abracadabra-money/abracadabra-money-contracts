// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {IERC20Metadata} from "openzeppelin-contracts/interfaces/IERC20Metadata.sol";
import {IAggregator} from "interfaces/IAggregator.sol";
import {IMagicLP} from "/mimswap/interfaces/IMagicLP.sol";

contract MagicLpAggregator is IAggregator {
    IMagicLP public immutable pair;
    IAggregator public immutable baseOracle;
    IAggregator public immutable quoteOracle;
    uint8 public immutable baseDecimals;
    uint8 public immutable quoteDecimals;

    uint256 public constant WAD = 18;

    /// @param pair_ The MagicLP pair address
    /// @param baseOracle_ The base oracle
    /// @param quoteOracle_ The quote oracle
    constructor(IMagicLP pair_, IAggregator baseOracle_, IAggregator quoteOracle_) {
        pair = pair_;
        baseOracle = baseOracle_;
        quoteOracle = quoteOracle_;
        baseDecimals = IERC20Metadata(pair_._BASE_TOKEN_()).decimals();
        quoteDecimals = IERC20Metadata(pair_._QUOTE_TOKEN_()).decimals();
    }

    function decimals() external pure override returns (uint8) {
        return 18;
    }

    function _getReserves() internal view virtual returns (uint256, uint256) {
        return pair.getReserves();
    }

    function latestAnswer() public view override returns (int256) {
        uint256 baseAnswerNomalized = uint256(baseOracle.latestAnswer()) * (10 ** (WAD - baseOracle.decimals()));
        uint256 quoteAnswerNormalized = uint256(quoteOracle.latestAnswer()) * (10 ** (WAD - quoteOracle.decimals()));
        uint256 minAnswer = baseAnswerNomalized < quoteAnswerNormalized ? baseAnswerNomalized : quoteAnswerNormalized;

        (uint256 baseReserve, uint256 quoteReserve) = _getReserves();
        baseReserve = baseReserve * (10 ** (WAD - baseDecimals));
        quoteReserve = quoteReserve * (10 ** (WAD - quoteDecimals));
        return int256(minAnswer * (baseReserve + quoteReserve) / pair.totalSupply());
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (0, latestAnswer(), 0, 0, 0);
    }
}