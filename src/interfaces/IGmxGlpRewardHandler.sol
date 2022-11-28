// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/interfaces/IERC20.sol";

interface IGmxGlpRewardHandler {
    function harvest() external;

    function swapRewards(
        uint256 amountOutMin,
        IERC20 rewardToken,
        IERC20 outputToken,
        address recipient,
        bytes calldata data
    ) external returns (uint256 amountOut);
}
