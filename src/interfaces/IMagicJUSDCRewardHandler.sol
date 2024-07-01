// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {IMiniChefV2} from "interfaces/IMiniChefV2.sol";

interface IMagicJUSDCRewardHandler {
    function harvest(address to) external;

    function distributeRewards(uint256 amount) external;

    function stakeAsset(uint256 amount) external;

    function unstakeAsset(uint256 amount) external;

    function skimAssets() external returns (uint256, uint256);

    function stakingInfo() external view returns (IMiniChefV2 staking, uint96 pid);

    function setStaking(IMiniChefV2 staking) external;

    function isPrivateDelegateFunction(bytes4 sig) external view returns (bool);
}
