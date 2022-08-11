// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface IVelodromePairFactory {
    function volatileFee() external view returns (uint256);
    function stableFee() external view returns (uint256);
}
