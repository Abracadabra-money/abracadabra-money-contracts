// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/interfaces/IERC20.sol";
import "interfaces/ILevelFinanceStaking.sol";

/// @notice Fixes innacurate pending rewards calculation in Level Finance staking contract.
contract LevelFinanceStakingLens {
    uint256 private constant ACC_REWARD_PRECISION = 1e12;
    ILevelFinanceStaking public immutable staking;

    constructor(ILevelFinanceStaking _staking) {
        staking = _staking;
    }

    function _simulateUpdatePool(uint256 pid) private view returns (ILevelFinanceStaking.PoolInfo memory pool) {
        pool = staking.poolInfo(pid);
        if (block.timestamp > pool.lastRewardTime) {
            uint256 lpSupply = IERC20(staking.lpToken(pid)).balanceOf(address(this));
            if (lpSupply != 0) {
                uint256 time = block.timestamp - pool.lastRewardTime;
                pool.accRewardPerShare =
                    pool.accRewardPerShare +
                    uint128(
                        (time * staking.rewardPerSecond() * pool.allocPoint * ACC_REWARD_PRECISION) / staking.totalAllocPoint() / lpSupply
                    );
            }
        }
    }

    function pendingRewards(uint256 pid, address user) external view returns (uint256) {
        ILevelFinanceStaking.PoolInfo memory pool = _simulateUpdatePool(pid);
        (uint256 amount, int256 rewardDebt) = staking.userInfo(pid, user);
        int256 accumulatedReward = int256((amount * pool.accRewardPerShare) / ACC_REWARD_PRECISION);
        return uint256(accumulatedReward - rewardDebt);
    }
}
