// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2021 BoringCrypto - All rights reserved
pragma solidity >=0.8.0;

import {DegenBox} from "/DegenBox.sol";
import {RebaseLibrary, Rebase} from "BoringSolidity/libraries/BoringRebase.sol";
import {BoringMath, BoringMath128} from "BoringSolidity/libraries/BoringMath.sol";
import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {YieldMode, GasMode, IBlast} from "interfaces/IBlast.sol";
import {OperatableV3} from "mixins/OperatableV3.sol";

interface IDegenBoxBlast {
    function harvestNativeYields(IERC20 _token, uint256 _claimAmount) external;
}

contract DegenBoxBlast is DegenBox, OperatableV3 {
    using BoringMath for uint256;
    using BoringMath128 for uint128;
    using RebaseLibrary for Rebase;

    event LogNativeYieldHarvested(IERC20 indexed token, uint256 amount);

    error ErrNotEnoughClaimed();

    IBlast constant BLAST_YIELD_PRECOMPILE = IBlast(0x4300000000000000000000000000000000000002);

    constructor(IERC20 _weth) DegenBox(_weth) {}

    function _configure() internal override {
        BLAST_YIELD_PRECOMPILE.configureClaimableYield();
        BLAST_YIELD_PRECOMPILE.configureClaimableGas();
    }

    function harvestNativeYields(IERC20 _token, uint256 _claimAmount) external onlyOperators {
        if (_claimAmount == type(uint256).max) {
            _claimAmount = BLAST_YIELD_PRECOMPILE.readClaimableYield(address(_token));
        }

        uint256 balanceBefore = _token.balanceOf(address(this));
        uint256 claimedAmount = BLAST_YIELD_PRECOMPILE.claimYield(address(_token), address(this), _claimAmount);

        // Safety check to ensure we got the yield amount
        if (_token.balanceOf(address(this)) < balanceBefore + claimedAmount) {
            revert ErrNotEnoughClaimed();
        }

        uint256 totalElastic = totals[_token].elastic;

        totalElastic = totalElastic.add(claimedAmount);
        totals[_token].elastic = totalElastic.to128();

        emit LogNativeYieldHarvested(_token, claimedAmount);
    }

    function claimAllGas() external onlyOwner {
        BLAST_YIELD_PRECOMPILE.claimAllGas(address(this), owner);
    }

    function isOwner(address _account) internal view override returns (bool) {
        return owner == _account;
    }
}
