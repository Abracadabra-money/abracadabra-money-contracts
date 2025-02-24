// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface IBalancerV2Vault {
    enum UserBalanceOpKind {
        DEPOSIT_INTERNAL,
        WITHDRAW_INTERNAL,
        TRANSFER_INTERNAL,
        TRANSFER_EXTERNAL
    }
    struct UserBalanceOp {
        UserBalanceOpKind kind;
        address asset;
        uint256 amount;
        address sender;
        address payable recipient;
    }

    function getPoolTokens(
        bytes32 poolId
    ) external view returns (address[] memory tokens, uint256[] memory balances, uint256 lastChangeBlock);

    function manageUserBalance(UserBalanceOp[] memory ops) external payable;
}
