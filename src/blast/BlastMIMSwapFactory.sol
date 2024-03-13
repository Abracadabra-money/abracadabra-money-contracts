// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {BlastYields} from "/blast/libraries/BlastYields.sol";
import {Factory} from "/mimswap/periphery/Factory.sol";
import {IFeeRateModel} from "/mimswap/interfaces/IFeeRateModel.sol";

contract BlastMIMSwapFactory is Factory {
    constructor(
        address implementation_,
        IFeeRateModel maintainerFeeRateModel_,
        address owner_,
        address governor_
    ) Factory(implementation_, maintainerFeeRateModel_, owner_) {
        if (governor_ == address(0)) {
            revert ErrZeroAddress();
        }
        BlastYields.configureDefaultClaimables(governor_);
    }
}
