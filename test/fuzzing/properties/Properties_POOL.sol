// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./PropertiesBase.sol";

/**
 * @title Properties_POOL
 * @author 0xScourgedev
 * @notice Contains all POOL invariants
 */
abstract contract Properties_POOL is PropertiesBase {
    function invariant_POOL_01(address pool) internal {
        uint256 sum = 0;
        for (uint8 i = 0; i < USERS.length; i++) {
            sum += states[1].actorStates[USERS[i]].tokenBalances[pool];
        }
        sum += states[1].poolStates[pool].addressZeroBal;
        sum += states[1].poolStates[pool].poolLpTokenBal;
        eq(sum, states[1].poolStates[pool].lpTotalSupply, POOL_01);
    }

    function invariant_POOL_02() internal {
        t(false, POOL_02);
    }

    function invariant_POOL_03() internal {
        t(false, POOL_03);
    }

    function invariant_POOL_04(address pool) internal {
        bool isZero = states[1].poolStates[pool].lpTotalSupply == 0;
        bool gte1001 = states[1].poolStates[pool].lpTotalSupply >= 1001;
        t(isZero || gte1001, POOL_04);
    }
}
