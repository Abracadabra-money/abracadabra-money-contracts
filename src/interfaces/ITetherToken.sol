// SPDX-License-Identifier: MIT
// solhint-disable func-name-mixedcase, var-name-mixedcase
pragma solidity >=0.8.0;

interface ITetherToken {
    function approve(address _spender, uint256 _value) external;
    function balanceOf(address user) external view returns (uint256);
}