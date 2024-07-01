// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

interface IJonesRouter {
    function underlyingVault() external view returns (address);

    function deposit(uint256 _assets, address _receiver) external returns (uint256);

    function withdraw(address _receiver, uint256 _minAmountOut, bytes memory _enforceData) external returns (uint256);

    function withdrawCooldown() external view returns (uint256);

    function withdrawRequest(
        uint256 _shares,
        address _receiver,
        uint256 _minAmountOut,
        bytes memory _enforceData
    ) external returns (bool, uint256);
}
