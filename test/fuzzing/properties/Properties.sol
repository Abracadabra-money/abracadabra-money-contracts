// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./Properties_LIQ.sol";
import "./Properties_RES.sol";
import "./Properties_POOL.sol";
import "./Properties_SWAP.sol";

/**
 * @title Properties
 * @author 0xScourgedev
 * @notice Composite contract for all of the properties, and contains general invariants
 */
abstract contract Properties is Properties_LIQ, Properties_RES, Properties_POOL, Properties_SWAP {
    function invariant_GENERAL_01(bytes memory returnData) internal {
        gte(returnData.length, 4, GENERAL_01);
    }
}
