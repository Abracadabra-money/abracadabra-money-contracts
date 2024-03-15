// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "fuzzlib/IHevm.sol";

/**
 * @title FuzzConstants
 * @author 0xScourgedev
 * @notice Constants and assumptions for the fuzzing suite
 */
abstract contract FuzzConstants {
    bool internal constant DEBUG = false;

    address internal constant USER1 = address(0x10000);
    address internal constant USER2 = address(0x20000);
    address internal constant USER3 = address(0x30000);
    address[] internal USERS = [USER1, USER2, USER3];

    uint256 internal constant INITIAL_BALANCE = 500_000 ether; // 1 Billion USD worth of ETH at $2000/ETH
    uint256 internal constant INITIAL_WETH_BALANCE = 500_000 ether; // 1 Billion USD worth of WETH at $2000/ETH
    uint256 internal constant INITIAL_TOKEN_BALANCE = 5_000_000_000_000; // 5 trillion tokens, to be multiplied by decimals in setup
    uint256 internal constant REASONABLE_PREVIEW_AMOUNT = type(uint96).max; // 1 Billion USD as the upper bound of reasonable amount

    uint256 internal constant MAX_POOLS = 16;
    uint8 internal constant MAX_PATH_LENGTH = 5;

    // MagicLP constants
    uint256 internal constant MAX_I = 10 ** 36;
    uint256 internal constant MAX_K = 10 ** 18;
    uint256 internal constant MIN_LP_FEE_RATE = 1e14; // 0.01%
    uint256 internal constant MAX_LP_FEE_RATE = 1e16; // 1%
}
