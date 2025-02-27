// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

interface IInfraredStaking {
    struct Reward {
        address rewardsDistributor;
        uint256 rewardsDuration;
        uint256 periodFinish;
        uint256 rewardRate;
        uint256 lastUpdateTime;
        uint256 rewardPerTokenStored;
        uint256 rewardResidual;
    }

    struct UserReward {
        address token;
        uint256 amount;
    }

    function totalSupply() external view returns (uint256);

    function stake(uint256 amount) external;

    function withdraw(uint256 amount) external;

    function getReward() external;

    function exit() external;

    function balanceOf(address account) external view returns (uint256);

    function lastTimeRewardApplicable(address _rewardsToken) external view returns (uint256);

    function rewardPerToken(address _rewardsToken) external view returns (uint256);

    function earned(address account, address _rewardsToken) external view returns (uint256);

    function getRewardForDuration(address _rewardsToken) external view returns (uint256);

    function rewardData(
        address _rewardsToken
    )
        external
        view
        returns (
            address rewardsDistributor,
            uint256 rewardsDuration,
            uint256 periodFinish,
            uint256 rewardRate,
            uint256 lastUpdateTime,
            uint256 rewardPerTokenStored,
            uint256 rewardResidual
        );

    function rewardTokens(uint256 index) external view returns (address);

    function getRewardForUser(address _user) external;

    function getAllRewardTokens() external view returns (address[] memory);

    function getAllRewardsForUser(address _user) external view returns (UserReward[] memory);

    function infrared() external view returns (address);

    function rewardsVault() external view returns (address);
}
