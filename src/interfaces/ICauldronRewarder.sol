// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/interfaces/IERC20.sol";

interface ICauldronRewarder {
    function ACC_REWARD_PER_SHARE_PRECISION() external view returns (uint256);

    function accRewardPerShare() external view returns (uint256);

    function deposit(address _from, uint256 _collateralShare) external;

    function harvest(address to) external returns (uint256 overshoot);

    function harvestMultiple(address[] memory to) external;

    function lastRewardBalance() external view returns (uint256);

    function pendingReward(address _user) external view returns (uint256);

    function updateReward(IERC20) external;

    function updateReward() external;

    function userInfo(address) external view returns (uint256 amount, int256 rewardDebt);

    function withdraw(address from, uint256 _collateralShare) external;
}
