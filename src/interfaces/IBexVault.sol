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

interface IBexVault {
    function joinPool(bytes32 poolId, address sender, address recipient, JoinPoolRequest memory request) external payable;

    function exitPool(bytes32 poolId, address sender, address payable recipient, ExitPoolRequest memory request) external;

    function getPoolTokens(
        bytes32 poolId
    ) external view returns (address[] memory tokens, uint256[] memory balances, uint256 lastChangeBlock);
}
