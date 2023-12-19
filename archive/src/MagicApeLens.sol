// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "interfaces/IApeCoinStaking.sol";

contract MagicAPELens {
    uint256 constant PRECISION = 1e18;
    uint256 constant BPS_PRECISION = 1e4;
    address public constant APE_COIN_STAKING_CONTRACT = 0x5954aB967Bc958940b7EB73ee84797Dc8a2AFbb9;
    address public constant APE_COIN_CONTRACT = 0x4d224452801ACEd8B2F0aebE155379bb5D594381;

    struct PoolInfo {
        uint256 apr;
        uint256 stakedAmount;
        uint256 poolRewardsPerHour;
        uint256 poolRewardsPerDay;
        uint256 rewardPerHour;
        uint256 poolRewardsPerTokenPerDay;
    }

    function getApeCoinInfo() external view returns (PoolInfo memory info) {
        (IApeCoinStaking.PoolUI memory apeCoinInfo, , , ) = IApeCoinStaking(APE_COIN_STAKING_CONTRACT).getPoolsUI();
        return getPoolInfo(apeCoinInfo);
    }

    function getBAYCInfo() external view returns (PoolInfo memory info) {
        (, IApeCoinStaking.PoolUI memory baycInfo, , ) = IApeCoinStaking(APE_COIN_STAKING_CONTRACT).getPoolsUI();
        return getPoolInfo(baycInfo);
    }

    function getMAYCInfo() external view returns (PoolInfo memory info) {
        (, , IApeCoinStaking.PoolUI memory maycInfo, ) = IApeCoinStaking(APE_COIN_STAKING_CONTRACT).getPoolsUI();
        return getPoolInfo(maycInfo);
    }

    function getBAKCInfo() external view returns (PoolInfo memory info) {
        (, , , IApeCoinStaking.PoolUI memory bakcInfo) = IApeCoinStaking(APE_COIN_STAKING_CONTRACT).getPoolsUI();
        return getPoolInfo(bakcInfo);
    }

    function getPoolInfo(IApeCoinStaking.PoolUI memory poolUI) public pure returns (PoolInfo memory info) {
        uint256 poolRewardsPerHour = poolUI.currentTimeRange.rewardsPerHour;
        uint256 poolRewardsPerDay = poolRewardsPerHour * 24;
        uint256 poolRewardsPerTokenPerHour = computeRewardPerHour(uint256(poolRewardsPerHour), poolUI.stakedAmount);
        uint256 poolRewardsPerTokenPerDay = poolRewardsPerTokenPerHour * 24;
        uint256 apr = (poolRewardsPerTokenPerDay * 365 * BPS_PRECISION) / PRECISION;

        return
            PoolInfo(
                apr,
                poolUI.stakedAmount,
                poolRewardsPerHour,
                poolRewardsPerDay,
                poolRewardsPerTokenPerHour,
                poolRewardsPerTokenPerDay
            );
    }

    function computeRewardPerHour(uint256 poolRewardsPerHour, uint256 stakedAmount) public pure returns (uint256 rewardPerHour) {
        return (poolRewardsPerHour * PRECISION) / stakedAmount;
    }
}
