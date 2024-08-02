// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

interface IKodiakIsland {
    function getUnderlyingBalancesAtPrice(uint160 sqrtRatioX96) external view returns (uint256 reserve0, uint256 reserve1);

    function totalSupply() external view returns (uint256);

    function token0() external view returns (address);

    function token1() external view returns (address);
}
