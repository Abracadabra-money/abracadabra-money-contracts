// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IBalancerV2Vault} from "/interfaces/IBalancerV2Vault.sol";

library BalancerV2VaultReentrancyLib {
    function ensureNotInVaultContext(IBalancerV2Vault vault) internal view {
        // Use low-level static call
        // Will always revert in reentrancy check modifier:
        // - If reentrancy because of the reentrancy guard, revertData.length > 0
        // - If not reentrancy because of modifying state which static calls do not permit, revertData.length == 0
        (, bytes memory revertData) = address(vault).staticcall(
            abi.encodeCall(vault.manageUserBalance, new IBalancerV2Vault.UserBalanceOp[](0))
        );
        // Only check length as it always reverts
        require(revertData.length == 0);
    }
}
