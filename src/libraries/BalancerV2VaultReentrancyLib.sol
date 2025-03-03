// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity >=0.8.27;

import {IBalancerV2Vault} from "/interfaces/IBalancerV2Vault.sol";

/// @author Adapted from: https://github.com/balancer/balancer-v2-monorepo/blob/36d282374b457dddea828be7884ee0d185db06ba/pkg/pool-utils/contracts/lib/VaultReentrancyLib.sol
library BalancerV2VaultReentrancyLib {
    error ErrVaultInContext();

    function ensureNotInVaultContext(IBalancerV2Vault vault) internal view {
        // Use low-level static call
        // Will always revert in reentrancy check modifier:
        // - If reentrancy because of the reentrancy guard, revertData.length > 0
        // - If not reentrancy because of modifying state which static calls do not permit, revertData.length == 0
        (, bytes memory revertData) = address(vault).staticcall(
            abi.encodeCall(vault.manageUserBalance, new IBalancerV2Vault.UserBalanceOp[](0))
        );
        // Only check length as it always reverts
        require(revertData.length == 0, ErrVaultInContext());
    }
}
