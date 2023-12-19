// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface ISwapperV1 {
    function swap(
        address fromToken,
        address toToken,
        address recipient,
        uint256 shareToMin,
        uint256 shareFrom
    ) external returns (uint256 extraShare, uint256 shareReturned);
}