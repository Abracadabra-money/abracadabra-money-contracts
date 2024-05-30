// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {BlastYields} from "/blast/libraries/BlastYields.sol";
import {Router} from "/mimswap/periphery/Router.sol";
import {IWETH} from "interfaces/IWETH.sol";
import {IFactory} from "/mimswap/interfaces/IFactory.sol";

contract BlastMIMSwapRouter is Router {
    constructor(IWETH weth_, IFactory factory, address governor_) Router(weth_, factory) {
        if (governor_ == address(0)) {
            revert ErrZeroAddress();
        }
        BlastYields.configureDefaultClaimables(governor_);
    }
}
