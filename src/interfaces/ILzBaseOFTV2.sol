// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface ILzBaseOFTV2 {
    function sharedDecimals() external view returns (uint8);

    function innerToken() external view returns (address);
}
