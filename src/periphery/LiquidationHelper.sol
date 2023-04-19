// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/ERC20.sol";
import "libraries/CauldronLib.sol";
import "interfaces/IBentoBoxV1.sol";
import "interfaces/ICauldronV2.sol";
import "interfaces/ICauldronV3.sol";
import "interfaces/ICauldronV4.sol";

/// @title LiquidationHelper
/// @notice Helper contract to liquidate accounts using max borrow amount or a part of it.
/// The required MiM is transferred from the liquidator to the BentoBox in case there's not enough balance
/// inside the user degenbox to cover the liquidation.
contract LiquidationHelper {
    error ErrInvalidCauldronVersion(uint8 cauldronVersion);

    ERC20 public mim;

    constructor(ERC20 _mim) {
        mim = _mim;
    }

    function isLiquidatable(ICauldronV2 cauldron, address account) public view returns (bool) {
        return !CauldronLib.isSolvent(cauldron, account);
    }

    function previewLiquidation(
        ICauldronV2 cauldron,
        address account,
        uint256 borrowPart
    ) external view returns (bool liquidatable, uint256 requiredMIMAmount, uint256 returnedCollateralAmount) {
        uint256 maxBorrowPart = cauldron.userBorrowPart(account);
        if (borrowPart > maxBorrowPart) {
            borrowPart = maxBorrowPart;
        }
        liquidatable = isLiquidatable(cauldron, account);
        (returnedCollateralAmount, requiredMIMAmount) = CauldronLib.getLiquidationCollateralAndBorrowAmount(
            ICauldronV2(cauldron),
            borrowPart
        );
    }

    /// @notice Liquidate an account using max borrow amount
    function liquidateMax(
        address cauldron,
        address account,
        uint8 cauldronVersion
    ) external returns (uint256 collateralAmount, uint256 borrowAmount) {
        return liquidateMaxTo(cauldron, account, msg.sender, cauldronVersion);
    }

    /// @notice Liquidate an account using max borrow amount and send the collateral to a different address
    function liquidateMaxTo(
        address cauldron,
        address account,
        address recipient,
        uint8 cauldronVersion
    ) public returns (uint256 collateralAmount, uint256 borrowAmount) {
        uint256 borrowPart = ICauldronV2(cauldron).userBorrowPart(account);
        return liquidateTo(cauldron, account, recipient, borrowPart, cauldronVersion);
    }

    /// @notice Liquidate an account using a part of the borrow amount
    function liquidate(
        address cauldron,
        address account,
        uint256 borrowPart,
        uint8 cauldronVersion
    ) external returns (uint256 collateralAmount, uint256 borrowAmount) {
        return liquidateTo(cauldron, account, msg.sender, borrowPart, cauldronVersion);
    }

    /// @notice Liquidate an account using a part of the borrow amount and send the collateral to a different address
    function liquidateTo(
        address cauldron,
        address account,
        address recipient,
        uint256 borrowPart,
        uint8 cauldronVersion
    ) public returns (uint256 collateralAmount, uint256 borrowAmount) {
        (collateralAmount, borrowAmount) = CauldronLib.getLiquidationCollateralAndBorrowAmount(ICauldronV2(cauldron), borrowPart);

        IBentoBoxV1 box = IBentoBoxV1(ICauldronV2(cauldron).bentoBox());
        uint256 shareMIMBefore = _transferRequiredMiMToCauldronDegenBox(box, borrowAmount);

        IERC20 collateral = ICauldronV2(cauldron).collateral();
        address masterContract = address(ICauldronV2(cauldron).masterContract());
        box.setMasterContractApproval(address(this), masterContract, true, 0, 0, 0);

        address[] memory users = new address[](1);
        users[0] = account;
        uint256[] memory maxBorrowParts = new uint256[](1);
        maxBorrowParts[0] = borrowPart;

        if (cauldronVersion <= 2) {
            ICauldronV2(cauldron).liquidate(users, maxBorrowParts, address(this), address(0));
        } else if (cauldronVersion == 3) {
            ICauldronV3(cauldron).liquidate(users, maxBorrowParts, address(this), address(0), new bytes(0));
        } else if (cauldronVersion == 4) {
            ICauldronV4(cauldron).liquidate(users, maxBorrowParts, address(this), address(0), new bytes(0));
        } else {
            revert ErrInvalidCauldronVersion(cauldronVersion);
        }

        box.setMasterContractApproval(address(this), masterContract, false, 0, 0, 0);

        // withdraw/refund any MiM left and withdraw collateral to wallet
        box.withdraw(mim, address(this), msg.sender, 0, box.balanceOf(mim, address(this)) - shareMIMBefore);
        box.withdraw(collateral, address(this), recipient, 0, box.balanceOf(collateral, address(this)));
    }

    /// @notice Transfer MiM from the liquidator to the BentoBox
    function _transferRequiredMiMToCauldronDegenBox(IBentoBoxV1 box, uint256 amount) internal returns (uint256 shareMIMBefore) {
        shareMIMBefore = box.balanceOf(mim, address(this));
        mim.transferFrom(msg.sender, address(box), amount);
        box.deposit(mim, address(box), address(this), amount, 0);
    }
}
