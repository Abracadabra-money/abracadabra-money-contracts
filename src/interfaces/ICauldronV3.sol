// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "interfaces/ICauldronV2.sol";

interface ICauldronV3 is ICauldronV2 {
    function changeInterestRate(ICauldronV3 cauldron, uint64 newInterestRate) external;

    function changeBorrowLimit(uint128 newBorrowLimit, uint128 perAddressPart) external;
}
