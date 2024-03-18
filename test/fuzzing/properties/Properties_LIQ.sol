// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./PropertiesBase.sol";

/**
 * @title Properties_LIQ
 * @author 0xScourgedev
 * @notice Contains all LIQ invariants
 */
abstract contract Properties_LIQ is PropertiesBase {
    function invariant_LIQ_01(address pool) internal {
        if (states[0].poolStates[pool].baseBalance > 0 || states[0].poolStates[pool].quoteBalance > 0) {
            return;
        }
        gt(states[1].poolStates[pool].baseBalance, states[0].poolStates[pool].baseBalance, LIQ_01);
        gt(states[1].poolStates[pool].quoteBalance, states[0].poolStates[pool].quoteBalance, LIQ_01);
    }

    function invariant_LIQ_02(address pool, bool supplyETH) internal {
        if (states[0].poolStates[pool].baseBalance > 0 || states[0].poolStates[pool].quoteBalance > 0) {
            return;
        }

        if (supplyETH) {
            address tokenToCheck;
            if (MagicLP(pool)._BASE_TOKEN_() == address(weth)) {
                tokenToCheck = MagicLP(pool)._QUOTE_TOKEN_();
            } else {
                tokenToCheck = MagicLP(pool)._BASE_TOKEN_();
            }

            lt(
                states[1].actorStates[currentActor].tokenBalances[tokenToCheck],
                states[0].actorStates[currentActor].tokenBalances[tokenToCheck],
                LIQ_02
            );
            lt(states[1].actorStates[currentActor].ethBalance, states[0].actorStates[currentActor].ethBalance, LIQ_02);
        } else {
            lt(
                states[1].actorStates[currentActor].tokenBalances[MagicLP(pool)._BASE_TOKEN_()],
                states[0].actorStates[currentActor].tokenBalances[MagicLP(pool)._BASE_TOKEN_()],
                LIQ_02
            );
            lt(
                states[1].actorStates[currentActor].tokenBalances[MagicLP(pool)._QUOTE_TOKEN_()],
                states[0].actorStates[currentActor].tokenBalances[MagicLP(pool)._QUOTE_TOKEN_()],
                LIQ_02
            );
        }
    }

    function invariant_LIQ_03(address pool) internal {
        gt(states[1].poolStates[pool].lpTotalSupply, states[0].poolStates[pool].lpTotalSupply, LIQ_03);
    }

    function invariant_LIQ_04(address pool) internal {
        gt(states[1].actorStates[currentActor].tokenBalances[pool], states[0].actorStates[currentActor].tokenBalances[pool], LIQ_04);
    }

    function invariant_LIQ_05(address pool) internal {
        lte(states[1].poolStates[pool].baseBalance, states[0].poolStates[pool].baseBalance, LIQ_05);
        lte(states[1].poolStates[pool].quoteBalance, states[0].poolStates[pool].quoteBalance, LIQ_05);
    }

    function invariant_LIQ_06(address pool, bool supplyETH) internal {
        if (supplyETH) {
            address tokenToCheck;
            if (MagicLP(pool)._BASE_TOKEN_() == address(weth)) {
                tokenToCheck = MagicLP(pool)._QUOTE_TOKEN_();
            } else {
                tokenToCheck = MagicLP(pool)._BASE_TOKEN_();
            }

            gte(
                states[1].actorStates[currentActor].tokenBalances[tokenToCheck],
                states[0].actorStates[currentActor].tokenBalances[tokenToCheck],
                LIQ_06
            );
            gte(states[1].actorStates[currentActor].ethBalance, states[0].actorStates[currentActor].ethBalance, LIQ_06);
        } else {
            gte(
                states[1].actorStates[currentActor].tokenBalances[MagicLP(pool)._BASE_TOKEN_()],
                states[0].actorStates[currentActor].tokenBalances[MagicLP(pool)._BASE_TOKEN_()],
                LIQ_06
            );
            gte(
                states[1].actorStates[currentActor].tokenBalances[MagicLP(pool)._QUOTE_TOKEN_()],
                states[0].actorStates[currentActor].tokenBalances[MagicLP(pool)._QUOTE_TOKEN_()],
                LIQ_06
            );
        }
    }

    function invariant_LIQ_07(address pool, uint256 sharesIn) internal {
        if (sharesIn > 0) {
            lt(states[1].poolStates[pool].lpTotalSupply, states[0].poolStates[pool].lpTotalSupply, LIQ_07);
        }
    }

    function invariant_LIQ_08(address pool, uint256 sharesIn) internal {
        if (sharesIn > 0) {
            lt(states[1].actorStates[currentActor].tokenBalances[pool], states[0].actorStates[currentActor].tokenBalances[pool], LIQ_08);
        }
    }

    function invariant_LIQ_09(address pool, uint256 sharesIn) internal {
        if (sharesIn == 0) {
            eq(
                states[1].actorStates[currentActor].tokenBalances[MagicLP(pool)._BASE_TOKEN_()],
                states[0].actorStates[currentActor].tokenBalances[MagicLP(pool)._BASE_TOKEN_()],
                LIQ_09
            );
            eq(
                states[1].actorStates[currentActor].tokenBalances[MagicLP(pool)._QUOTE_TOKEN_()],
                states[0].actorStates[currentActor].tokenBalances[MagicLP(pool)._QUOTE_TOKEN_()],
                LIQ_09
            );
            eq(states[1].actorStates[currentActor].ethBalance, states[0].actorStates[currentActor].ethBalance, LIQ_09);
        }
    }

    function invariant_LIQ_10() internal {
        t(false, LIQ_10);
    }

    function invariant_LIQ_11(address pool) internal {
        if (MagicLP(pool).totalSupply() > 0) {
            t(false, LIQ_11);
        }
    }

    function invariant_LIQ_12(uint256 preview, uint256 actual) internal {
        gte(preview, actual, LIQ_12);
    }

    function invariant_LIQ_13(uint256 preview, uint256 actual) internal {
        eq(preview, actual, LIQ_13);
    }

    function invariant_LIQ_14(uint256 previewBase, uint256 previewQuote, uint256 actualBase, uint256 actualQuote) internal {
        eq(previewBase, actualBase, LIQ_14);
        eq(previewQuote, actualQuote, LIQ_14);
    }
}
