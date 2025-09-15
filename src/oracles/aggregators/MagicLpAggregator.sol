// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {FixedPointMathLib} from "@solady/utils/FixedPointMathLib.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {IAggregator} from "/interfaces/IAggregator.sol";
import {IMagicLP} from "/mimswap/interfaces/IMagicLP.sol";
import {PMMPricing} from "/mimswap/libraries/PMMPricing.sol";

contract MagicLpAggregator is IAggregator {
    using FixedPointMathLib for uint256;

    IMagicLP public immutable pair;
    IAggregator public immutable baseOracle;
    IAggregator public immutable quoteOracle;
    uint8 public immutable baseDecimals;
    uint8 public immutable quoteDecimals;

    uint8 internal constant WAD = 18;
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
        (, int256 baseOracleAnswer, , , ) = baseOracle.latestRoundData();
        uint256 baseAnswerNormalized = uint256(baseOracleAnswer) * (10 ** (WAD - baseOracle.decimals()));
        (, int256 quoteOracleAnswer, , , ) = quoteOracle.latestRoundData();
        uint256 quoteAnswerNormalized = uint256(quoteOracleAnswer) * (10 ** (WAD - quoteOracle.decimals()));

        uint256 i = pair._I_() * 10 ** (baseDecimals - quoteDecimals);
        uint256 k = pair._K_();

        uint256 baseTargetNormalized = uint256(pair._BASE_TARGET_()) * (10 ** (WAD - baseDecimals));
        uint256 quoteTargetNormalized = uint256(pair._QUOTE_TARGET_()) * (10 ** (WAD - quoteDecimals));

        uint256 B;
        uint256 Q;

        if (quoteTargetNormalized * quoteAnswerNormalized <= baseTargetNormalized * baseAnswerNormalized) {
            // RState.ONE/RState.BELOW_ONE
            // solve(P_B/P_Q = i * (1 - k + (B_0/B)^2 * k), B)
            // Positve solution: sqrt(P_Q*i*k/(P_Q*i*k - P_Q*i + P_B))*B_0
            // B_0 * sqrt((i*k*P_Q)/(P_B + i*k*P_Q - i*P_Q))
            uint256 ipq = i.mulWad(quoteAnswerNormalized);
            uint256 ikpq = ipq.mulWad(k);

            uint256 ikpqpb = ikpq + baseAnswerNormalized;
            if (ikpqpb <= ipq) {
                B = baseTargetNormalized;
                Q = 0;
            } else {
                uint256 denominator;
                unchecked {
                    denominator = ikpqpb - ipq;
                }
                B = baseTargetNormalized.mulWad(ikpq.divWad(denominator).sqrtWad());

                if (B == 0) {
                    Q = quoteTargetNormalized;
                } else {
                    // solve(Q - Q_0 = i * (B_0 - B) * (1 + k *(B_0/B - 1)), Q)
                    // Solution: Q_0 + (i * (B_0 - B) * (1 + k * (B_0/B - 1)))
                    uint256 r = i.mulWad(ONE + (k * baseTargetNormalized) / B - k);
                    Q = (quoteTargetNormalized * ONE + baseTargetNormalized * r - B * r) / ONE;
                }
            }
        } else {
            // RState.ABOVE_ONE
            // solve(P_B/P_Q = i / (1 - k + (Q_0/Q)^2 * k), Q)
            // Positive solution: Q_0*sqrt(k*P_B/(k*P_B + i*P_Q - P_B))
            uint256 kpb = k.mulWad(baseAnswerNormalized);
            uint256 kpbipq = kpb + i.mulWad(quoteAnswerNormalized);
            if (kpbipq <= baseAnswerNormalized) {
                Q = quoteTargetNormalized;
                B = 0;
            } else {
                uint256 denominator;
                unchecked {
                    denominator = kpbipq - baseAnswerNormalized;
                }
                Q = quoteTargetNormalized.mulWad((kpb.divWad(denominator)).sqrtWad());

                if (Q == 0) {
                    B = baseTargetNormalized;
                } else {
                    // solve(B - B_0 = ((Q_0 - Q) * (1 + k * (Q_0/Q - 1)))/i, B)
                    // Solution: B_0 + (((Q_0 - Q) * (1 + k * (Q_0/Q - 1)))/i)
                    uint256 r = (ONE + (k * quoteTargetNormalized) / Q - k);
                    B = (baseTargetNormalized * i + (quoteTargetNormalized * r) - (Q * r)) / i;
                }
            }
        }

        return int256((baseAnswerNormalized * B + quoteAnswerNormalized * Q) / (pair.totalSupply() * (10 ** (WAD - baseDecimals))));
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (0, latestAnswer(), 0, 0, 0);
    }
}
