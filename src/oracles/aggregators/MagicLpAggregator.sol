// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {FixedPointMathLib} from "@solady/utils/FixedPointMathLib.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {IAggregator} from "/interfaces/IAggregator.sol";
import {IMagicLP} from "/mimswap/interfaces/IMagicLP.sol";

contract MagicLpAggregator is IAggregator {
    using FixedPointMathLib for uint256;

    IMagicLP public immutable pair;
    IAggregator public immutable baseOracle;
    IAggregator public immutable quoteOracle;
    uint8 public immutable baseDecimals;
    uint8 public immutable quoteDecimals;

    uint8 public constant WAD = 18;
    uint256 internal constant ONE = 1e18;

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
        return WAD;
    }

    function latestAnswer() public view override returns (int256) {
        uint256 baseAnswerNomalized = uint256(baseOracle.latestAnswer()) * (10 ** (WAD - baseOracle.decimals()));
        uint256 quoteAnswerNormalized = uint256(quoteOracle.latestAnswer()) * (10 ** (WAD - quoteOracle.decimals()));

        uint256 baseTargetNormalized = pair._BASE_TARGET_() * (10 ** (WAD - baseDecimals));
        uint256 quoteTargetNormalized = pair._QUOTE_TARGET_() * (10 ** (WAD - quoteDecimals));

        uint256 k = pair._K_();
        uint256 i = pair._I_() * 10 ** (baseDecimals - quoteDecimals);

        uint256 B;
        uint256 Q;

        // uint256 initialPrice = quoteTargetNormalized.divWad(baseTargetNormalized);
        // uint256 price = baseAnswerNomalized.divWad(quoteAnswerNormalized);
        // if (initialPrice < price) {
        if (quoteTargetNormalized.divWad(baseTargetNormalized) <= baseAnswerNomalized.divWad(quoteAnswerNormalized)) {
            uint256 qai = quoteAnswerNormalized.mulWad(i);
            uint256 qaik = qai.mulWad(k);
            B = (qaik.divWad(qaik - qai + baseAnswerNomalized)).sqrtWad().mulWad(baseTargetNormalized);
            Q = quoteTargetNormalized + i.mulWad(baseTargetNormalized - B).mulWad(ONE + k.mulWad(baseTargetNormalized.divWad(B) - ONE));
            // } else if (initialPrice > price) {
        } else {
            uint256 bak = baseAnswerNomalized.mulWad(k);
            Q = baseTargetNormalized.mulWad((bak.divWad(quoteAnswerNormalized.mulWad(i) + bak - baseAnswerNomalized)).sqrtWad());
            B =
                baseTargetNormalized +
                ((quoteTargetNormalized - Q).mulWad(ONE + k.mulWad(quoteTargetNormalized.divWad(Q) - ONE))).divWad(i);
        } /* else {
            return int256(pair._I_()); // TODO: Normalize decimals & consider conversion or to remove branch
            }*/

        return
            int256(
                (baseAnswerNomalized.mulWad(B) + quoteAnswerNormalized.mulWad(Q)).divWad(pair.totalSupply() ** (10 ** (WAD - baseDecimals)))
            );
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (0, latestAnswer(), 0, 0, 0);
    }
}
