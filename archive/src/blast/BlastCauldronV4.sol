// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {BlastYields} from "/blast/libraries/BlastYields.sol";
import {CauldronV4} from "cauldrons/CauldronV4.sol";
import {IBentoBoxV1} from "interfaces/IBentoBoxV1.sol";

contract BlastCauldronV4 is CauldronV4 {
    error ErrZeroAddress();
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
        _setupBlacklist();
    }

    function init(bytes calldata data) public payable override {
        if (_governor == address(this)) {
            revert ErrInvalidGovernorAddress();
        }

        _setupBlacklist();

        super.init(data);
        BlastYields.configureDefaultClaimables(_governor);
    }

    function _setupBlacklist() private {
        blacklistedCallees[address(BlastYields.BLAST_YIELD_PRECOMPILE)] = true;
    }
}
