// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {LzIndirectOFTV2} from "tokens/LzIndirectOFTV2.sol";
import {BlastYields} from "/blast/libraries/BlastYields.sol";
import {IMintableBurnable} from "interfaces/IMintableBurnable.sol";

contract BlastLzIndirectOFTV2 is LzIndirectOFTV2 {
    error ErrZeroAddress();

    constructor(
        address _token,
        IMintableBurnable _minterBurner,
        uint8 _sharedDecimals,
        address _lzEndpoint,
        address _owner,
        address governor_
    ) LzIndirectOFTV2(_token, _minterBurner, _sharedDecimals, _lzEndpoint, _owner) {
        if (governor_ == address(0)) {
            revert ErrZeroAddress();
        }
        
        BlastYields.configureDefaultClaimables(governor_);
    }
}
