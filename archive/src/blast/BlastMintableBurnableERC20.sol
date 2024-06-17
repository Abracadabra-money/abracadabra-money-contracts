// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {MintableBurnableERC20} from "tokens/MintableBurnableERC20.sol";
import {BlastYields} from "/blast/libraries/BlastYields.sol";

contract BlastMintableBurnableERC20 is MintableBurnableERC20 {
    error ErrZeroAddress();

    constructor(
        address _owner,
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address governor_
    ) MintableBurnableERC20(_owner, name_, symbol_, decimals_) {
        if (governor_ == address(0)) {
            revert ErrZeroAddress();
        }
        BlastYields.configureDefaultClaimables(governor_);
    }
}
