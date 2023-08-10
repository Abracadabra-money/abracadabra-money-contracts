// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface ICurveRewardGauge {
    function claim_rewards(address account, address to) external;

    function deposit(uint256 amount, address account, bool claimRewards) external;

    function withdraw(uint256 amount) external;

    function balanceOf(address account) external view returns (uint256);

    function reward_count() external view returns (uint256);

    function reward_tokens() external view returns (address[] memory);

    function claimable_reward(address account, address rewardToken) external view returns (uint256);
}
