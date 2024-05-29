pragma solidity >=0.8.0;
/*

    Copyright 2020 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

import {DecimalMath} from "/mimswap/libraries/DecimalMath.sol";
import {MagicLP} from "/mimswap/MagicLP.sol";
import {PMMPricing} from "/mimswap/libraries/PMMPricing.sol";

contract MagicLPLens {
    function getMidPrice(address lp) external view returns (uint256) {
        PMMPricing.PMMState memory state = MagicLP(lp).getPMMState();
        if (state.R == PMMPricing.RState.BELOW_ONE) {
            uint256 R = DecimalMath.divFloor((state.Q0 * state.Q0) / state.Q, state.Q);
            R = DecimalMath.ONE - state.K + DecimalMath.mulFloor(state.K, R);
            return DecimalMath.divFloor(state.i, R);
        } else {
            uint256 R = DecimalMath.divFloor((state.B0 * state.B0) / state.B, state.B);
            R = DecimalMath.ONE - state.K + DecimalMath.mulFloor(state.K, R);
            return DecimalMath.mulFloor(state.i, R);
        }
    }
}
