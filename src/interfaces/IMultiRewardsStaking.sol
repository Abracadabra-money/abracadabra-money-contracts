// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface IMultiRewardsStaking {
    struct Reward {
        uint256 rewardsDuration;
        uint256 periodFinish;
        uint256 rewardRate;
        uint256 lastUpdateTime;
        uint256 rewardPerTokenStored;
    }

    function addReward(address rewardToken, uint256 _rewardsDuration) external;

    function balanceOf(address user) external view returns (uint256 amount);

    function earned(address user, address rewardToken) external view returns (uint256);

    function exit() external;

    function getRewardForDuration(address rewardToken) external view returns (uint256);

    function getRewards() external;

    function lastTimeRewardApplicable(address rewardToken) external view returns (uint256);

    function notifyRewardAmount(address rewardToken, uint256 amount) external;

    function operators(address) external view returns (bool);

    function owner() external view returns (address);

    function pause() external;

    function paused() external view returns (bool);

    function recover(address tokenAddress, uint256 tokenAmount) external;

    function rewardData(address token) external view returns (Reward memory);

    function rewardPerToken(address rewardToken) external view returns (uint256);

    function rewardTokens(uint256) external view returns (address);

    function rewards(address user, address token) external view returns (uint256 amount);

    function setOperator(address operator, bool status) external;

    function setRewardsDuration(address rewardToken, uint256 _rewardsDuration) external;

    function stake(uint256 amount) external;

    function stakingToken() external view returns (address);

    function totalSupply() external view returns (uint256);

    function transferOwnership(address newOwner) external;

    function unpause() external;

    function userRewardPerTokenPaid(address user, address token) external view returns (uint256 amount);

    function getRewardTokenLength() external view returns (uint256);

    function isSupportedReward(address rewardToken) external view returns (bool);

    function withdraw(uint256 amount) external;
}
