// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./PreconditionsBase.sol";

/**
 * @title PreconditionsMagicLP
 * @author 0xScourgedev
 * @notice Contains all preconditions for MagicLP
 */
abstract contract PreconditionsMagicLP is PreconditionsBase {
    struct SellSharesParams {
        uint256 shareAmount;
        address lpAddr;
        uint256 baseMinAmount;
        uint256 quoteMinAmount;
        uint256 deadline;
    }

    struct TransferParams {
        address lpAddr;
        uint256 amount;
    }

    struct TransferTokensToLpParams {
        address token;
        address lpAddr;
        uint256 amount;
    }

    function buySharesPreconditions(uint8 lp) internal view returns (address) {
        require(allPools.length > 0, "There are no available pools");
        return allPools[lp % allPools.length];
    }

    function correctRStatePreconditions(uint8 lp) internal view returns (address) {
        require(allPools.length > 0, "There are no available pools");
        return allPools[lp % allPools.length];
    }

    function sellBasePreconditions(uint8 lp) internal view returns (address) {
        require(allPools.length > 0, "There are no available pools");
        return allPools[lp % allPools.length];
    }

    function sellQuotePreconditions(uint8 lp) internal view returns (address) {
        require(allPools.length > 0, "There are no available pools");
        return allPools[lp % allPools.length];
    }

    function sellSharesPreconditions(
        uint256 shareAmount,
        uint8 lp,
        uint256 baseMinAmount,
        uint256 quoteMinAmount,
        uint256 deadline
    ) internal view returns (SellSharesParams memory) {
        require(allPools.length > 0, "There are no available pools");

        address lpAddr = allPools[lp % allPools.length];
        return SellSharesParams(shareAmount, lpAddr, baseMinAmount, quoteMinAmount, deadline);
    }

    function syncPreconditions(uint8 lp) internal view returns (address) {
        require(allPools.length > 0, "There are no available pools");

        return allPools[lp % allPools.length];
    }

    function transferSharesToLpPreconditions(uint8 lp, uint256 amount) internal returns (TransferParams memory) {
        require(allPools.length > 0, "There are no available pools");

        address lpAddr = allPools[lp % allPools.length];

        amount = clampBetween(amount, 0, IERC20(lpAddr).balanceOf(address(currentActor)));

        vm.prank(currentActor);
        IERC20(lpAddr).approve(lpAddr, amount);

        return TransferParams(lpAddr, amount);
    }

    function transferTokensToLpPreconditions(
        uint8 lp,
        bool transferQuote,
        uint256 amount
    ) internal returns (TransferTokensToLpParams memory) {
        require(allPools.length > 0, "There are no available pools");

        address lpAddr = allPools[lp % allPools.length];
        address token;
        if (transferQuote) {
            token = MagicLP(lpAddr)._QUOTE_TOKEN_();
        } else {
            token = MagicLP(lpAddr)._BASE_TOKEN_();
        }

        amount = clampBetween(amount, 0, IERC20(token).balanceOf(address(currentActor)));

        vm.prank(currentActor);
        IERC20(token).approve(lpAddr, amount);

        return TransferTokensToLpParams(token, lpAddr, amount);
    }
}
