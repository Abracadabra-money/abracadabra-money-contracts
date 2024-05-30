// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {BlastYields} from "/blast/libraries/BlastYields.sol";
import {FeeRateModel} from "/mimswap/auxiliary/FeeRateModel.sol";
import {FeeRateModelImpl} from "/mimswap/auxiliary/FeeRateModelImpl.sol";

contract BlastFeeRateModel is FeeRateModel {
    constructor(address maintainer_, address owner_, address governor_) FeeRateModel(maintainer_, owner_) {
        if (governor_ == address(0)) {
            revert ErrZeroAddress();
        }
        BlastYields.configureDefaultClaimables(governor_);
    }
}

contract BlastFeeRateModelImpl is FeeRateModelImpl {
    error ErrZeroAddress();

    constructor(address governor_) {
        if (governor_ == address(0)) {
            revert ErrZeroAddress();
        }
        BlastYields.configureDefaultClaimables(governor_);
    }
}
