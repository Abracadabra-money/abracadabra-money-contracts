// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {LzOFTV2FeeHandler} from "periphery/LzOFTV2FeeHandler.sol";
import {BlastYields} from "/blast/libraries/BlastYields.sol";
import {IBlastLzOFTV2FeeHandler} from "/blast/interfaces/IBlastLzOFTV2FeeHandler.sol";
import {IBlastLzOFTV2Wrapper} from "/blast/interfaces/IBlastLzOFTV2Wrapper.sol";

/// @dev This contract holds ETH from fees and accumulates
/// ETH yields to claim.
contract BlastLzOFTV2FeeHandler is LzOFTV2FeeHandler, IBlastLzOFTV2FeeHandler {
    error ErrZeroAddress();
    error ErrNotFromWrapper();

    IBlastLzOFTV2Wrapper public immutable oftWrapper;

    constructor(
        address _owner,
        uint256 _fixedNativeFee,
        address _oft,
        address _aggregator,
        address _feeTo,
        uint8 _quoteType,
        address _governor,
        IBlastLzOFTV2Wrapper _oftWrapper
    ) LzOFTV2FeeHandler(_owner, _fixedNativeFee, _oft, _aggregator, _feeTo, _quoteType) {
        if (_governor == address(0)) {
            revert ErrZeroAddress();
        }

        BlastYields.configureDefaultClaimables(_governor);
        oftWrapper = _oftWrapper;
    }

    ////////////////////////////////////////////////////////////////////
    /// Views
    ////////////////////////////////////////////////////////////////////

    // The oft wrapper cannot be bridged directly and must
    // go through the OFTWrapper.
    function getFee() public view override returns (uint256) {
        if (!oftWrapper.inTransit()) {
            revert ErrNotFromWrapper();
        }
        return super.getFee();
    }

    function getFeeNoTransitCheck() public view override returns (uint256) {
        return super.getFee();
    }
}
