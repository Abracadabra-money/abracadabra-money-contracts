// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {BlastYields} from "/blast/libraries/BlastYields.sol";
import {Router} from "/mimswap/periphery/Router.sol";
import {Factory} from "/mimswap/periphery/Factory.sol";
import {IFeeRateModel} from "/mimswap/interfaces/IFeeRateModel.sol";
import {CauldronV4} from "cauldrons/CauldronV4.sol";
import {IWETH} from "interfaces/IWETH.sol";
import {IBentoBoxV1} from "interfaces/IBentoBoxV1.sol";
import {IFactory} from "/mimswap/interfaces/IFactory.sol";

/// @dev Collection of Blast wrapped contract that are succecptible to be used
/// enough to justify claiming gas yields.

error ErrZeroAddress();

contract BlastMIMSwapRouter is Router {
    constructor(IWETH weth_, IFactory factory, address governor_) Router(weth_, factory) {
        if (governor_ == address(0)) {
            revert ErrZeroAddress();
        }
        BlastYields.configureDefaultClaimables(governor_);
    }
}

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

contract BlastCauldronV4 is CauldronV4 {
    error ErrInvalidGovernorAddress();

    address private immutable _governor;

    constructor(address box_, address mim_, address governor_) CauldronV4(IBentoBoxV1(box_), IERC20(mim_)) {
        if (governor_ == address(0)) {
            revert ErrZeroAddress();
        }
        if (governor_ == address(this)) {
            revert ErrInvalidGovernorAddress();
        }

        _governor = governor_;
    }

    function init(bytes calldata data) public payable override {
        if (_governor == address(this)) {
            revert ErrInvalidGovernorAddress();
        }

        super.init(data);
        BlastYields.configureDefaultClaimables(_governor);
    }
}
