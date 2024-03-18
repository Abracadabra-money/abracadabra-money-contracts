// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

/**
 * @title PropertiesDescriptions
 * @author 0xScourgedev
 * @notice Descriptions strings for the invariants
 */
abstract contract PropertiesDescriptions {
    string constant GENERAL_01 = "GENERAL-01: Does not silent revert";

    string constant LIQ_01 =
        "LIQ-01: If the base and quote token balance is 0, the amount of base tokens and quote tokens in the pool is always strictly increasing after adding liquidity";
    string constant LIQ_02 =
        "LIQ-02: If the base and quote token balance is 0, the amount of base and quote tokens of the user is always strictly decreasing after adding liquidity";
    string constant LIQ_03 = "LIQ-03: The total supply of lp tokens is always strictly increasing after adding liquidity";
    string constant LIQ_04 = "LIQ-04: The lp token balance of the user is always strictly increasing after adding liquidity";

    string constant LIQ_05 = "LIQ-05: The amount of base tokens and quote tokens in the pool is always decreasing after removing liquidity";
    string constant LIQ_06 = "LIQ-06: The amount of base and quote tokens of the user is always increasing after removing liquidity";
    string constant LIQ_07 = "LIQ-07: The total supply of lp tokens is always strictly decreasing after removing liquidity";
    string constant LIQ_08 = "LIQ-08: The lp token balance of the user is always strictly decreasing after removing liquidity";
    string constant LIQ_09 = "LIQ-09: Base and quote tokens are never transfered to the user for free when removing liquidity";

    string constant LIQ_10 = "LIQ-10: previewAddLiquidity() never reverts for reasonable values";
    string constant LIQ_11 =
        "LIQ-11: previewRemoveLiquidity() never reverts for reasonable values if the total supply of lp tokens is greater than 0";
    string constant LIQ_12 = "LIQ-12: Adding liquidity must provide less or equal shares to the user predicted by previewAddLiquidity()";
    string constant LIQ_13 = "LIQ-13: Adding liquidity unsafe must provide exact shares to the user predicted by previewAddLiquidity()";
    string constant LIQ_14 =
        "LIQ-14: Removing liquidity must provide the same amount of base and quote tokens to the user predicted by previewRemoveLiquidity()";

    string constant RES_01 = "RES-01: If the quote reserve and base reserve of a pool is 0, then the lp total supply must be 0";
    string constant RES_02 = "RES-02: The base reserve of a pool is always less than or equal to the pool base balance";
    string constant RES_03 = "RES-03: The quote reserve of a pool is always less than or equal to the pool quote balance";

    string constant POOL_01 =
        "POOL-01: The sum of the LP token balances held by each user is always equal to the total supply of LP tokens";
    string constant POOL_02 = "POOL-02: sync() must never revert";
    string constant POOL_03 = "POOL-03: correctRState() must never revert";
    string constant POOL_04 = "POOL-04: The total supply of LP tokens is either 0 or always greater or equal to 1001";

    string constant SWAP_01 = "SWAP-01: Swap must decrease the input token balance of the user if the input and output token are different";
    string constant SWAP_02 =
        "SWAP-02: Swap must increase the output token balance of the user if the input and output token are different";
    string constant SWAP_03 =
        "SWAP-03: The swap must credit the user with an amount of the output token that is equal to or greater than the specified minimumOut";
}
