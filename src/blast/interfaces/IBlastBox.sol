// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

interface IBlastBox {
    function feeTo() external view returns (address);

    function registry() external view returns (address);

    function setTokenEnabled(address token, bool enabled) external;

    function claimNativeYields() external returns (uint256 gasAmount, uint256 nativeAmount);

    function claimTokenYields(address token_) external returns (uint256 amount);

    function setFeeTo(address feeTo_) external;

    function enabledTokens(address) external view returns (bool);
}
