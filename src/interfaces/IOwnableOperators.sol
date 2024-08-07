// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

interface IOwnableOperators {
    function owner() external view returns (address);

    function operators(address) external view returns (bool);

    function setOperator(address operator, bool status) external;

    function transferOwnership(address newOwner) external;
}
