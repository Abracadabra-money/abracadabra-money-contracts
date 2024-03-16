// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./PropertiesBase.sol";

/**
 * @title Properties_SWAP
 * @author 0xScourgedev
 * @notice Contains all SWAP invariants
 */
abstract contract Properties_SWAP is PropertiesBase {
    function invariant_SWAP_01(address inputToken, address outputToken, bool isEth) internal {
        if (isEth) {
            lte(states[1].actorStates[currentActor].ethBalance, states[0].actorStates[currentActor].ethBalance, SWAP_01);
        } else {
            if (inputToken == outputToken) {
                return;
            }
            lte(
                states[1].actorStates[currentActor].tokenBalances[inputToken],
                states[0].actorStates[currentActor].tokenBalances[inputToken],
                SWAP_01
            );
        }
    }

    function invariant_SWAP_02(address inputToken, address outputToken, bool isEth) internal {
        if (isEth) {
            gte(states[1].actorStates[currentActor].ethBalance, states[0].actorStates[currentActor].ethBalance, SWAP_02);
        } else {
            if (inputToken == outputToken) {
                return;
            }
            gte(
                states[1].actorStates[currentActor].tokenBalances[outputToken],
                states[0].actorStates[currentActor].tokenBalances[outputToken],
                SWAP_02
            );
        }
    }

    function invariant_SWAP_03(uint256 actualOut, uint256 minimumOut) internal {
        gte(actualOut, minimumOut, SWAP_03);
    }
}
