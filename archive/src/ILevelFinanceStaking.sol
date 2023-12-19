// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "interfaces/ILevelFinanceLiquidityPool.sol";

interface ILevelFinanceStaking {
    struct PoolInfo {
        uint128 accRewardPerShare;
        uint64 lastRewardTime;
        uint64 allocPoint;
        bool staking;
    }

    function poolInfo(uint256) external view returns (PoolInfo memory);

    function levelPool() external view returns (ILevelFinanceLiquidityPool);

    function weth() external view returns (address);

    function poolLength() external view returns (uint256);

    function updatePool(uint256 pid) external returns (PoolInfo memory);

    function userInfo(uint256 _pid, address _user) external view returns (uint256, int256);

    function deposit(uint256 pid, uint256 amount, address to) external;

    function withdraw(uint256 pid, uint256 amount, address to) external;

    function rewardToken() external view returns (address);

    function harvest(uint256 pid, address to) external;

    function withdrawAndHarvest(uint256 pid, uint256 amount, address to) external;

    function emergencyWithdraw(uint256 pid, address to) external;

    function lpToken(uint256 pid) external view returns (address);

    function pendingReward(uint256 _pid, address _user) external view returns (uint256);

    function rewardPerSecond() external view returns (uint256);

    function totalAllocPoint() external view returns (uint256);
}
