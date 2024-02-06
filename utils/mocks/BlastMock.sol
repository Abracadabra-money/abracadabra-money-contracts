// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IBlast, YieldMode, GasMode} from "interfaces/IBlast.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

import "forge-std/console2.sol";

/// @title BlastMock
/// @notice Mock contract for Blast L2, only supports claimable mode.
contract BlastMock is IBlast {
    using SafeTransferLib for address;

    mapping(address account => mapping(address token => uint256 amount)) claimableAmounts;
    mapping(address account => uint256 amount) claimableGas;

    function configure(YieldMode _yield, GasMode gasMode, address governor) external pure override {}

    function configureContract(address contractAddress, YieldMode _yield, GasMode gasMode, address governor) external {}

    function configureClaimableYield() external {}

    function configureClaimableYieldOnBehalf(address contractAddress) external {}

    function configureAutomaticYield() external {}

    function configureAutomaticYieldOnBehalf(address contractAddress) external {}

    function configureVoidYield() external {}

    function configureVoidYieldOnBehalf(address contractAddress) external {}

    function configureClaimableGas() external {}

    function configureClaimableGasOnBehalf(address contractAddress) external {}

    function configureVoidGas() external {}

    function configureVoidGasOnBehalf(address contractAddress) external {}

    function configureGovernor(address _governor) external {}

    function configureGovernorOnBehalf(address _newGovernor, address contractAddress) external {}

    function readClaimableYield(address token) external view override returns (uint256) {
        console2.log("here");
        return claimableAmounts[msg.sender][token];
    }

    function setClaimableAmount(address account, address token, uint256 amount) external {
        claimableAmounts[account][token] = amount;
    }

    function claimYield(address token, address recipient, uint256 amount) public override returns (uint256) {
        claimableAmounts[recipient][token] -= amount;
        token.safeTransfer(recipient, amount);
        return amount;
    }

    function claimAllYield(address contractAddress, address recipientOfYield) external returns (uint256) {
        return claimYield(contractAddress, recipientOfYield, claimableAmounts[recipientOfYield][contractAddress]);
    }

    function claimGas(
        address /*contractAddress*/,
        address recipientOfGas,
        uint256 gasToClaim,
        uint256 /*gasSecondsToConsume*/
    ) public returns (uint256) {
        claimableGas[recipientOfGas] -= gasToClaim;
        return gasToClaim;
    }

    function claimAllGas(address contractAddress, address recipientOfGas) external returns (uint256) {
        return claimGas(contractAddress, recipientOfGas, claimableGas[recipientOfGas], 0);
    }

    function claimGasAtMinClaimRate(address contractAddress, address recipientOfGas, uint256 /*minClaimRateBips*/) external returns (uint256) {
        return claimGas(contractAddress, recipientOfGas, claimableGas[recipientOfGas], 0);
    }

    function claimMaxGas(address contractAddress, address recipientOfGas) external returns (uint256) {
        return claimGas(contractAddress, recipientOfGas, claimableGas[recipientOfGas], 0);
    }

    function readYieldConfiguration(address /*contractAddress*/) external pure returns (uint8) {
        return uint8(YieldMode.CLAIMABLE);
    }

    function readGasParams(
        address /*contractAddress*/
    ) external pure returns (uint256 etherSeconds, uint256 etherBalance, uint256 lastUpdated, GasMode) {
        return (0, 0, 0, GasMode.CLAIMABLE);
    }
}
