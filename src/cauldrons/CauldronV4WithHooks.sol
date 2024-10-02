// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {IERC20} from "@BoringSolidity/interfaces/IERC20.sol";
import {IBentoBoxV1} from "/interfaces/IBentoBoxV1.sol";
import {CauldronV4} from "/cauldrons/CauldronV4.sol";
import {ICauldronV4Hooks} from "/interfaces/ICauldronV4Hooks.sol";

/// @title CauldronV4WithHooks
/// A cauldron version where every supported hooks are also called on the collateral token.
contract CauldronV4WithHooks is CauldronV4 {
    constructor(IBentoBoxV1 bentoBox_, IERC20 magicInternetMoney_, address owner_) CauldronV4(bentoBox_, magicInternetMoney_, owner_) {}

    ////////////////////////////////////////////////////////////////////////////////
    // BORROW
    ////////////////////////////////////////////////////////////////////////////////

    function _beforeBorrow(address from, address to, uint256 amount, uint256 newBorrowPart, uint256 part) internal override {
        ICauldronV4Hooks(address(collateral)).onBeforeBorrow(from, to, amount, newBorrowPart, part);
    }

    ////////////////////////////////////////////////////////////////////////////////
    // COLLATERAL
    ////////////////////////////////////////////////////////////////////////////////

    function _beforeAddCollateral(address from, address to, uint256 collateralShare) internal override {
        ICauldronV4Hooks(address(collateral)).onBeforeAddCollateral(from, to, collateralShare);
    }

    function _afterAddCollateral(address from, address to, uint256 collateralShare) internal override {
        ICauldronV4Hooks(address(collateral)).onAfterAddCollateral(from, to, collateralShare);
    }

    function _beforeRemoveCollateral(address from, address to, uint256 share) internal override {
        ICauldronV4Hooks(address(collateral)).onBeforeRemoveCollateral(from, to, share);
    }

    function _afterRemoveCollateral(address from, address to, uint256 collateralShare) internal override {
        ICauldronV4Hooks(address(collateral)).onAfterRemoveCollateral(from, to, collateralShare);
    }

    ////////////////////////////////////////////////////////////////////////////////
    // LIQUIDATION
    ////////////////////////////////////////////////////////////////////////////////

    function _beforeUsersLiquidated(address from, address[] memory users, uint256[] memory maxBorrowPart) internal override {
        ICauldronV4Hooks(address(collateral)).onBeforeUsersLiquidated(from, users, maxBorrowPart);
    }

    function _beforeUserLiquidated(
        address from,
        address user,
        uint256 borrowPart,
        uint256 borrowAmount,
        uint256 collateralShare
    ) internal override {
        ICauldronV4Hooks(address(collateral)).onBeforeUserLiquidated(from, user, borrowPart, borrowAmount, collateralShare);
    }

    function _afterUserLiquidated(address from, address to, uint256 collateralShare) internal override {
        ICauldronV4Hooks(address(collateral)).onAfterUserLiquidated(from, to, collateralShare);
    }
}
