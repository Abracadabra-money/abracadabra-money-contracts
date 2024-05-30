// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {LzOFTV2FeeHandler} from "periphery/LzOFTV2FeeHandler.sol";
import {BlastYields} from "/blast/libraries/BlastYields.sol";

/// @dev This contract holds ETH from fees and accumulates
/// ETH yields to claim.
contract BlastLzOFTV2FeeHandler is LzOFTV2FeeHandler {
    error ErrZeroAddress();

    constructor(
        address _owner,
        uint256 _fixedNativeFee,
        address _oft,
        address _aggregator,
        address _feeTo,
        uint8 _quoteType,
        address governor_
    ) LzOFTV2FeeHandler(_owner, _fixedNativeFee, _oft, _aggregator, _feeTo, _quoteType) {
        if (governor_ == address(0)) {
            revert ErrZeroAddress();
        }

        BlastYields.configureDefaultClaimables(governor_);
    }
}
