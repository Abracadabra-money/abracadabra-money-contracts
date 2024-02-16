// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

interface IBlastBox {
    function claimETHYields(uint256 amount) external returns (uint256);

    function claimTokenYields(address token, uint256 amount) external returns (uint256);

    function claimGasYields() external returns (uint256);

    function setTokenEnabled(address token, bool enabled, bool supportsNativeYields) external;
}
