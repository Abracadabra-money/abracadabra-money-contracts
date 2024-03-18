// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "../FuzzSetup.sol";

/**
 * @title BeforeAfter
 * @author 0xScourgedev
 * @notice Contains the states of the system before and after calls
 */
abstract contract BeforeAfter is FuzzSetup {
    mapping(uint8 => State) states;

    struct State {
        // actor => actorStates
        mapping(address => ActorStates) actorStates;
        mapping(address => PoolStates) poolStates;
    }

    struct ActorStates {
        mapping(address => uint256) tokenBalances;
        uint256 ethBalance;
    }

    struct PoolStates {
        uint256 baseBalance;
        uint256 quoteBalance;
        uint256 baseReserve;
        uint256 quoteReserve;
        uint256 baseTarget;
        uint256 quoteTarget;
        uint256 RState;
        uint256 lpTotalSupply;
        uint256 addressZeroBal;
        uint256 poolLpTokenBal;
    }

    function _before(address[] memory actors, address[] memory poolsToUpdate) internal {
        _setStates(0, actors, poolsToUpdate);
    }

    function _after(address[] memory actors, address[] memory poolsToUpdate) internal {
        _setStates(1, actors, poolsToUpdate);
    }

    function _setStates(uint8 callNum, address[] memory actors, address[] memory poolsToUpdate) internal {
        for (uint256 i = 0; i < actors.length; i++) {
            _setActorState(callNum, actors[i]);
        }

        for (uint256 i = 0; i < poolsToUpdate.length; i++) {
            if (poolsToUpdate[i] == address(0)) {
                break;
            }
            _setPoolState(callNum, poolsToUpdate[i]);
        }
    }

    function _setPoolState(uint8 callNum, address pool) internal {
        states[callNum].poolStates[pool].baseBalance = IERC20(MagicLP(pool)._BASE_TOKEN_()).balanceOf(pool);
        states[callNum].poolStates[pool].quoteBalance = IERC20(MagicLP(pool)._QUOTE_TOKEN_()).balanceOf(pool);
        states[callNum].poolStates[pool].baseReserve = MagicLP(pool)._BASE_RESERVE_();
        states[callNum].poolStates[pool].quoteReserve = MagicLP(pool)._QUOTE_RESERVE_();
        states[callNum].poolStates[pool].baseTarget = MagicLP(pool)._BASE_TARGET_();
        states[callNum].poolStates[pool].quoteTarget = MagicLP(pool)._QUOTE_TARGET_();
        states[callNum].poolStates[pool].RState = MagicLP(pool)._RState_();
        states[callNum].poolStates[pool].lpTotalSupply = IERC20(pool).totalSupply();
        states[callNum].poolStates[pool].addressZeroBal = IERC20(pool).balanceOf(address(0));
        states[callNum].poolStates[pool].poolLpTokenBal = IERC20(pool).balanceOf(pool);
    }

    function _setActorState(uint8 callNum, address actor) internal {
        states[callNum].actorStates[actor].ethBalance = actor.balance;
        for (uint256 i = 0; i < tokens.length; i++) {
            states[callNum].actorStates[actor].tokenBalances[address(tokens[i])] = IERC20(address(tokens[i])).balanceOf(actor);
        }
        for (uint256 i = 0; i < allPools.length; i++) {
            states[callNum].actorStates[actor].tokenBalances[allPools[i]] = IERC20(allPools[i]).balanceOf(actor);
        }
    }
}
