// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./PropertiesBase.sol";

/**
 * @title Properties_RES
 * @author 0xScourgedev
 * @notice Contains all RES invariants
 */
abstract contract Properties_RES is PropertiesBase {
    function invariant_RES_01(address pool) internal {
        if (states[1].poolStates[pool].baseReserve == 0 && states[1].poolStates[pool].quoteReserve == 0) {
            eq(states[1].poolStates[pool].lpTotalSupply, 0, RES_01);
        }
    }

    function invariant_RES_02(address pool) internal {
        lte(states[1].poolStates[pool].baseReserve, states[1].poolStates[pool].baseBalance, RES_02);
    }

    function invariant_RES_03(address pool) internal {
        lte(states[1].poolStates[pool].quoteReserve, states[1].poolStates[pool].quoteBalance, RES_03);
    }
}
