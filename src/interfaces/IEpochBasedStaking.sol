// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

interface IEpochBasedStaking {
    function epoch() external view returns (uint256);

    function nextEpoch() external view returns (uint256);

    function rewardData(
        address token
    ) external view returns (uint256 periodFinish, uint256 rewardRate, uint256 rewardPerTokenStored, bool exists, uint248 lastUpdateTime);

    function notifyRewardAmount(address rewardToken, uint256 amount, uint minRemainingTime) external;

    function rewardTokensLength() external view returns (uint);

    function rewardTokens(uint index) external view returns (address);

    function rewardsDuration() external view returns (uint256);
}