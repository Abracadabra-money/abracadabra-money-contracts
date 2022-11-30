// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/interfaces/IERC20.sol";
import "interfaces/IGmxRewardRouterV2.sol";

interface IGmxGlpRewardHandler {
    function harvest() external;

    function swapRewards(
        uint256 amountOutMin,
        IERC20 rewardToken,
        IERC20 outputToken,
        address recipient,
        bytes calldata data
    ) external returns (uint256 amountOut);

    function setFeeParameters(address _feeCollector, uint8 _feePercent) external;

    function setRewardTokenEnabled(IERC20 token, bool enabled) external;

    function setSwappingTokenOutEnabled(IERC20 token, bool enabled) external;

    function setAllowedSwappingRecipient(address recipient, bool enabled) external;

    function setRewardRouter(IGmxRewardRouterV2 _rewardRouter) external;

    function setSwapper(address _swapper) external;

    function unstakeGmx(uint256 amount, uint256 amountTransferToFeeCollector) external;

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
