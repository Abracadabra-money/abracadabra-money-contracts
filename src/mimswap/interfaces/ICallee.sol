/*

    Copyright 2020 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity >=0.8.0;

interface ICallee {
    function SellShareCall(
        address sender,
        uint256 burnShareAmount,
        uint256 baseAmount,
        uint256 quoteAmount,
        bytes calldata data
    ) external;

    function FlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external;
}
