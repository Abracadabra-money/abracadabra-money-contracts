// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

struct JoinPoolRequest {
    address[] assets;
    uint256[] maxAmountsIn;
    bytes userData;
    bool fromInternalBalance;
}

struct ExitPoolRequest {
    address[] assets;
    uint256[] minAmountsOut;
    bytes userData;
    bool toInternalBalance;
}

enum JoinKind {
    INIT,
    EXACT_TOKENS_IN_FOR_LP_OUT,
    TOKEN_IN_FOR_EXACT_LP_OUT,
    ALL_TOKENS_IN_FOR_EXACT_LP_OUT
}

enum ExitKind {
    EXACT_LP_IN_FOR_ONE_TOKEN_OUT,
    EXACT_LP_IN_FOR_TOKENS_OUT,
    LP_IN_FOR_EXACT_TOKENS_OUT
}

enum PoolSpecialization {
    GENERAL,
    MINIMAL_SWAP_INFO,
    TWO_TOKEN
}

interface IBexVault {
    function joinPool(bytes32 poolId, address sender, address recipient, JoinPoolRequest memory request) external payable;

    function exitPool(bytes32 poolId, address sender, address payable recipient, ExitPoolRequest memory request) external;

    function getPoolTokens(
        bytes32 poolId
    ) external view returns (address[] memory tokens, uint256[] memory balances, uint256 lastChangeBlock);

    function getPool(bytes32 poolId) external view returns (address, PoolSpecialization);
}
