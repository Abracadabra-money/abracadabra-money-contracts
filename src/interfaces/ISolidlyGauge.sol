// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface ISolidlyGauge {
    function earned(address token, address account) external view returns (uint256);

    function depositAll(uint256 tokenId) external;

    function deposit(uint256 amount, uint256 tokenId) external;

    function getReward(address account, address[] memory tokens) external;

    function withdrawAll() external;

    function withdraw(uint256 amount) external;

    function balanceOf(address account) external view returns (uint256);

    function notifyRewardAmount(address token, uint256 amount) external;
}
