// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ICauldronV2} from "interfaces/ICauldronV2.sol";

interface ICauldronV3 is ICauldronV2 {
    function borrowLimit() external view returns (uint128 total, uint128 borrowPartPerAddres);

    function changeInterestRate(uint64 newInterestRate) external;

    function changeBorrowLimit(uint128 newBorrowLimit, uint128 perAddressPart) external;

    function liquidate(
        address[] calldata users,
        uint256[] calldata maxBorrowParts,
        address to,
        address swapper,
        bytes calldata swapperData
    ) external;
}
