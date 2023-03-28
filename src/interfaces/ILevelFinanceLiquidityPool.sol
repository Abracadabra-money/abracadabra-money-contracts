// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface ILevelFinanceLiquidityPool {
    function getTrancheValue(address _tranche, bool _max) external view returns (uint256 sum);

    function addLiquidity(address _tranche, address _token, uint256 _amountIn, uint256 _minLpAmount, address _to) external;
}
