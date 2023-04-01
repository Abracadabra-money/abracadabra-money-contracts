// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/interfaces/IERC20.sol";
import "interfaces/ILevelFinanceStaking.sol";

interface IMagicLevelRewardHandler {
    function harvest(address to) external;

    function distributeRewards(uint256 amount) external;

    function stakeAsset(uint256 amount) external;

    function unstakeAsset(uint256 amount) external;

    function skimAssets() external returns (uint256, uint256);

    function stakingInfo() external view returns (ILevelFinanceStaking staking, uint96 pid);

    function setStakingInfo(ILevelFinanceStaking staking, uint96 pid) external;

    function isPrivateDelegateFunction(bytes4 sig) external view returns (bool);
}
