// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./PreconditionsBase.sol";

/**
 * @title PreconditionsFactory
 * @author 0xScourgedev
 * @notice Contains all preconditions for Factory
 */
abstract contract PreconditionsFactory is PreconditionsBase {
    struct CreateParams {
        address baseToken_;
        address quoteToken_;
        uint256 lpFeeRate_;
        uint256 i_;
        uint256 k_;
    }

    function createPreconditions(
        uint8 baseToken_,
        uint8 quoteToken_,
        uint256 lpFeeRate_,
        uint256 i_,
        uint256 k_
    ) internal returns (CreateParams memory) {
        require(allPools.length < MAX_POOLS, "Maximum number of pools reached");

        address baseToken = address(tokens[baseToken_ % tokens.length]);
        address quoteToken = address(tokens[quoteToken_ % tokens.length]);
        if(baseToken == quoteToken) {
            quoteToken = address(tokens[(quoteToken_ + 1) % tokens.length]);
        }
        
        lpFeeRate_ = clampBetween(lpFeeRate_, MIN_LP_FEE_RATE, MAX_LP_FEE_RATE);
        i_ = clampBetween(i_, 1, MAX_I);
        k_ = clampBetween(k_, 0, MAX_K);

        return CreateParams(baseToken, quoteToken, lpFeeRate_, i_, k_);
    }
}
