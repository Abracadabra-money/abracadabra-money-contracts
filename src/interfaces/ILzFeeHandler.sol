// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface ILzFeeHandler {
    enum QuoteType {
        None,
        Oracle,
        Fixed
    }

    function getFee() external view returns (uint256);
}
