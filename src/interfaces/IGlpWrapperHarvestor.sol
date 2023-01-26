// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "interfaces/IMimCauldronDistributor.sol";

interface IGlpWrapperHarvestor {
    function claimable() external view returns (uint256);

    function distributor() external view returns (IMimCauldronDistributor);

    function lastExecution() external view returns (uint64);

    function operators(address) external view returns (bool);

    function outputToken() external view returns (address);

    function owner() external view returns (address);

    function pendingOwner() external view returns (address);

    function rewardRouterV2() external view returns (address);

    function rewardToken() external view returns (address);

    function run(uint256 amountOutMin, bytes memory data) external;

    function setDistributor(address _distributor) external;

    function setOperator(address operator, bool status) external;

    function setOutputToken(address _outputToken) external;

    function setRewardRouterV2(address _rewardRouterV2) external;

    function setRewardToken(address _rewardToken) external;

    function totalRewardsBalanceAfterClaiming() external view returns (uint256);

    function wrapper() external view returns (address);
}
