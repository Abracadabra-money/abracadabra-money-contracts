// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0;

interface IKodiakVaultV1 {
    function name() external view returns (string memory);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function totalSupply() external view returns (uint256);

    function getUnderlyingBalancesAtPrice(uint160 sqrtRatioX96) external view returns (uint256 amount0Current, uint256 amount1Current);

    function getUnderlyingBalances() external view returns (uint256 amount0Current, uint256 amount1Current);
}

interface IKodiakVaultStaking {
    function earned(address account) external view returns (uint256[] memory new_earned);

    function emergencyWithdraw(bytes32 kek_id) external;

    function getAllRewardTokens() external view returns (address[] memory);

    function getReward() external returns (uint256[] memory);

    function rewardsPerToken() external view returns (uint256[] memory newRewardsPerTokenStored);

    function stakeLocked(uint256 liquidity, uint256 secs) external;

    function withdrawLockedAll() external;
}

interface IKodiakV1RouterStaking {
    function addLiquidity(
        IKodiakVaultV1 pool,
        uint256 amount0Max,
        uint256 amount1Max,
        uint256 amount0Min,
        uint256 amount1Min,
        uint256 amountSharesMin,
        address receiver
    ) external returns (uint256 amount0, uint256 amount1, uint256 mintAmount);

    function addLiquidityETH(
        IKodiakVaultV1 pool,
        uint256 amount0Max,
        uint256 amount1Max,
        uint256 amount0Min,
        uint256 amount1Min,
        uint256 amountSharesMin,
        address receiver
    ) external payable returns (uint256 amount0, uint256 amount1, uint256 mintAmount);

    function removeLiquidity(
        IKodiakVaultV1 pool,
        uint256 burnAmount,
        uint256 amount0Min,
        uint256 amount1Min,
        address receiver
    ) external returns (uint256 amount0, uint256 amount1, uint128 liquidityBurned);

    function removeLiquidityETH(
        IKodiakVaultV1 pool,
        uint256 burnAmount,
        uint256 amount0Min,
        uint256 amount1Min,
        address payable receiver
    ) external returns (uint256 amount0, uint256 amount1, uint128 liquidityBurned);
}
