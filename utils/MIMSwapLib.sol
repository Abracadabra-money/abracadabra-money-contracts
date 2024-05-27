// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Vm, VmSafe} from "forge-std/Vm.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {Router} from "/mimswap/periphery/Router.sol";
import {Toolkit} from "utils/Toolkit.sol";
import {IERC20Metadata} from "openzeppelin-contracts/interfaces/IERC20Metadata.sol";

library PoolType {
    uint256 internal constant AMM = 1 ether;
    uint256 internal constant PEGGED = 0.0001 ether; // price fluctuables within 0.5%
    uint256 internal constant LOOSELY_PEGGED = 0.00025 ether; // price fluctuables within 1.25%
    uint256 internal constant BARELY_PEGGED = 0.002 ether; // price fluctuables within 10%
}

library FeeRate {
    uint256 internal constant AMM = 0.003 ether; // 0.3%
    uint256 internal constant PEGGED = 0.0005 ether; // 0.05%
}

struct TokenInfo {
    address token;
    uint256 amount;
    uint256 priceInUsd;
}

library MIMSwapLib {
    Vm constant vm = Vm(address(bytes20(uint160(uint256(keccak256("hevm cheat code"))))));
    Toolkit constant toolkit = Toolkit(address(bytes20(uint160(uint256(keccak256("toolkit"))))));

    /**
        Example:

        TokenInfo memory base = TokenInfo({
            token: toolkit.getAddress(block.chainid, "weth"),
            amount: 0.01050574 * (10 ** 18),
            priceInUsd: 2_979.27 ether
        });

        TokenInfo memory quote = TokenInfo({
            token: toolkit.getAddress(block.chainid, "wbtc"),
            amount: 0.00049528 * (10 ** 8),
            priceInUsd: 60_418.58 ether
        });

        MIMSwapLib.createPool(PoolType.AMM, base, quote, true);
    */
    function createPool(
        uint256 poolType,
        TokenInfo memory base,
        TokenInfo memory quote,
        bool protocolOwnedPool
    ) internal returns (address clone, uint256 shares) {
        Router router = Router(payable(toolkit.getAddress(block.chainid, "mimswap.router")));
        uint256 i = calculateI(
            base.priceInUsd,
            quote.priceInUsd,
            IERC20Metadata(base.token).decimals(),
            IERC20Metadata(quote.token).decimals()
        );
        uint256 feeRate = FeeRate.AMM;

        if (poolType == PoolType.PEGGED || poolType == PoolType.LOOSELY_PEGGED || poolType == PoolType.BARELY_PEGGED) {
            feeRate = FeeRate.PEGGED;
        }

        SafeTransferLib.safeApprove(base.token, address(router), base.amount);
        SafeTransferLib.safeApprove(quote.token, address(router), quote.amount);

        (clone, shares) = router.createPool(
            base.token,
            quote.token,
            feeRate,
            i,
            poolType,
            msg.sender,
            base.amount,
            quote.amount,
            protocolOwnedPool
        );
    }

    function calculateI(
        uint256 basePriceInUSD,
        uint256 quotePriceInUSD,
        uint8 baseDecimals,
        uint8 quoteDecimals
    ) internal pure returns (uint256) {
        uint256 baseScale = 10 ** (18 + quoteDecimals);
        uint256 quoteScale = 10 ** baseDecimals;

        uint256 scaledBasePriceInUSD = basePriceInUSD * baseScale;
        uint256 scaledQuotePriceInUSD = quotePriceInUSD * quoteScale;

        return scaledBasePriceInUSD / scaledQuotePriceInUSD;
    }
}
