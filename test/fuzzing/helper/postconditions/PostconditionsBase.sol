// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "../../properties/Properties.sol";

/**
 * @title PostconditionsBase
 * @author 0xScourgedev
 * @notice Contains general postconditions used across all postcondition contracts
 */
abstract contract PostconditionsBase is Properties {
    function onSuccessInvariantsGeneral(address[] memory poolsToUpdate) internal {
        for (uint256 i = 0; i < poolsToUpdate.length; i++) {
            invariant_RES_01(poolsToUpdate[i]);
            invariant_RES_02(poolsToUpdate[i]);
            invariant_RES_03(poolsToUpdate[i]);
            invariant_POOL_01(poolsToUpdate[i]);
            invariant_POOL_04(poolsToUpdate[i]);
        }
    }

    function onFailInvariantsGeneral(bytes memory returnData) internal {
        invariant_GENERAL_01(returnData);
    }
}
