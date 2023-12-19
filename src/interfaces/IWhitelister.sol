// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

interface IWhitelister {
    function isBorrowingAllowed(address user, uint256 newBorrowPart) external view returns (bool success);

    function setMaxBorrow(address user, uint256 maxBorrow, bytes32[] calldata merkleProof) external returns (bool success);
}
