// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {ICurveRewardGauge} from "interfaces/ICurveRewardGauge.sol";

interface IMagicCurveLpRewardHandler {
    function harvest(address to) external;

    function distributeRewards(uint256 amount) external;

    function stakeAsset(uint256 amount) external;

    function unstakeAsset(uint256 amount) external;

    function skimAssets() external returns (uint256, uint256);

    function staking() external view returns (ICurveRewardGauge staking);

    function setStaking(ICurveRewardGauge staking) external;

    function isPrivateDelegateFunction(bytes4 sig) external view returns (bool);
}
