// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IBalancerV2Vault} from "/interfaces/IBalancerV2Vault.sol";

library BalancerV2VaultReentrancyLib {
    function ensureNotInVaultContext(IBalancerV2Vault vault) internal view {
        // Use low-level call allow it to be a view
        (, bytes memory revertData) = address(vault).staticcall(
            abi.encodeCall(vault.manageUserBalance, new IBalancerV2Vault.UserBalanceOp[](0))
        );
        // Only check length as rentrancy guard always reverts with revertData.length > 0
        require(revertData.length == 0);
    }
}
