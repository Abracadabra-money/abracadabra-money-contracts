// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface IStargatePool {
    function deltaCredit() external view returns (uint256);

    function totalLiquidity() external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function decimals() external view returns (uint256);

    function localDecimals() external view returns (uint256);

    function token() external view returns (address);
}
