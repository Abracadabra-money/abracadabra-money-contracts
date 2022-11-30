// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface IGmxRewardDistributor {
    function pendingRewards() external view returns (uint256);

    function distribute() external returns (uint256);
}
