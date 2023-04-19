// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "interfaces/ICauldronV3.sol";

interface ICauldronV4 is ICauldronV3 {
    function setBlacklistedCallee(address callee, bool blacklisted) external;

    function blacklistedCallees(address callee) external view returns (bool);

    function repayForAll(uint128 amount, bool skim) external returns (uint128);

    function liquidate(
        address[] memory users,
        uint256[] memory maxBorrowParts,
        address to,
        address swapper,
        bytes memory swapperData
    ) external;
}
