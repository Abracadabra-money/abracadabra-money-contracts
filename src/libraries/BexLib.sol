// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IBexVault, JoinPoolRequest, ExitPoolRequest, JoinKind, ExitKind, PoolSpecialization} from "../interfaces/IBexVault.sol";

IBexVault constant BEX_VAULT = IBexVault(0x4Be03f781C497A489E3cB0287833452cA9B9E80B);

/// @notice Library for interacting with the 2-tokens bex pools in a very high-level abstracted way
library BexLib {
    error ErrInvalidInput();
    error ErrInvalidNumTokens();
    error ErrInvalidPool();

    function getValidatedPool(bytes32 poolId) internal view returns (address pool) {
        PoolSpecialization specialization;
        (pool, specialization) = BEX_VAULT.getPool(poolId);
        require(specialization == PoolSpecialization.TWO_TOKEN, ErrInvalidPool());
    }

    function getPoolTokens(bytes32 poolId) internal view returns (address[] memory tokens) {
        (tokens, , ) = BEX_VAULT.getPoolTokens(poolId);
    }

    function joinPool(bytes32 poolId, address[] memory tokens, uint256[] memory amountsIn, uint256 minAmountOut, address to) internal {
        require(tokens.length == 2, ErrInvalidNumTokens());
        require(amountsIn.length == 2, ErrInvalidNumTokens());

        bytes memory userData = abi.encode(JoinKind.EXACT_TOKENS_IN_FOR_LP_OUT, amountsIn, minAmountOut);

        JoinPoolRequest memory request = JoinPoolRequest({
            assets: tokens,
            maxAmountsIn: amountsIn,
            userData: userData,
            fromInternalBalance: false
        });

        BEX_VAULT.joinPool(poolId, address(this), to, request);
    }

    function exitPool(bytes32 poolId, address[] memory tokens, uint256 amountIn, uint256[] memory minAmountsOut, address to) internal {
        require(tokens.length == 2, ErrInvalidNumTokens());

        bytes memory userData = abi.encode(ExitKind.EXACT_LP_IN_FOR_TOKENS_OUT, amountIn);

        ExitPoolRequest memory request = ExitPoolRequest({
            assets: tokens,
            minAmountsOut: minAmountsOut,
            userData: userData,
            toInternalBalance: false
        });

        BEX_VAULT.exitPool(poolId, address(this), payable(to), request);
    }
}
