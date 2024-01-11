// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface IBerachainBex {
    function getPreviewSharesForSingleSidedLiquidityRequest(
        address pool,
        address asset,
        uint256 amount
    ) external view returns (address[] memory assets, uint256[] memory amounts);

    function getRemoveLiquidityExactAmountOut(
        address pool,
        address assetIn,
        uint256 assetAmount
    ) external view returns (address[] memory assets, uint256[] memory amounts);

    function getRemoveLiquidityOneSideOut(
        address pool,
        address assetOut,
        uint256 sharesIn
    ) external view returns (address[] memory assets, uint256[] memory amounts);

    function addLiquidity(
        address pool,
        address receiver,
        address[] memory assetsIn,
        uint256[] memory amountsIn
    )
        external
        payable
        returns (address[] memory shares, uint256[] memory shareAmounts, address[] memory liquidity, uint256[] memory liquidityAmounts);

    function removeLiquidityBurningShares(
        address pool,
        address withdrawAddress,
        address assetIn,
        uint256 amountIn
    ) external payable returns (address[] memory liquidity, uint256[] memory liquidityAmounts);

    function removeLiquidityExactAmount(
        address pool,
        address withdrawAddress,
        address assetOut,
        uint256 amountOut,
        address sharesIn,
        uint256 maxSharesIn
    )
        external
        payable
        returns (address[] memory shares, uint256[] memory shareAmounts, address[] memory liquidity, uint256[] memory liquidityAmounts);
}
