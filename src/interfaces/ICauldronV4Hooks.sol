// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

interface ICauldronV4Hooks {
    function onBeforeAddCollateral(address from, address to, uint256 share) external;

    function onAfterAddCollateral(address from, address to, uint256 collateralShare) external;

    function onBeforeBorrow(address from, address to, uint256 amount, uint256 newBorrowPart, uint256 part) external;

    function onBeforeRemoveCollateral(address from, address to, uint256 share) external;

    function onAfterRemoveCollateral(address from, address to, uint256 collateralShare) external;

    function onBeforeUsersLiquidated(address from, address[] memory users, uint256[] memory maxBorrowPart) external;

    function onBeforeUserLiquidated(address from, address user, uint256 borrowPart, uint256 borrowAmount, uint256 collateralShare) external;

    function onAfterUserLiquidated(address from, address to, uint256 collateralShare) external;
}
