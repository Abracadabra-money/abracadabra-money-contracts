// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {IGmxRewardRouterV2} from "interfaces/IGmxV1.sol";

interface IMagicGlpRewardHandler {
    function harvest() external;

    function setRewardRouter(IGmxRewardRouterV2 _rewardRouter) external;

    function distributeRewards(uint256 amount) external;

    function skimAssets() external returns (uint256);

    function unstakeGmx(
        uint256 amount,
        uint256 amountToTransferToSender,
        address recipient
    ) external;

    function unstakeEsGmxAndVest(
        uint256 amount,
        uint256 glpVesterDepositAmount,
        uint256 gmxVesterDepositAmount
    ) external;

    function withdrawFromVesting(
        bool withdrawFromGlpVester,
        bool withdrawFromGmxVester,
        bool stake
    ) external;

    function claimVestedGmx(
        bool withdrawFromGlpVester,
        bool withdrawFromGmxVester,
        bool stake,
        bool transferToFeeCollecter
    ) external;
}
