// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "../../properties/Properties.sol";
import "./PostconditionsBase.sol";

/**
 * @title PostconditionsFactory
 * @author 0xScourgedev
 * @notice Contains all postconditions for Factory
 */
abstract contract PostconditionsFactory is PostconditionsBase {
    function createPostconditions(
        bool success,
        bytes memory returnData,
        address[] memory actorsToUpdate,
        address[] memory poolsToUpdate,
        address baseToken,
        address quoteToken
    ) internal {
        if (success) {
            address pool = abi.decode(returnData, (address));
            allPools.push(pool);
            pools[baseToken][quoteToken] = pool;
            pools[quoteToken][baseToken] = pool;
            availablePools[quoteToken].push(pool);
            availablePools[baseToken].push(pool);
            poolsToUpdate[0] = pool;

            _after(actorsToUpdate, poolsToUpdate);
            onSuccessInvariantsGeneral(poolsToUpdate);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }
}
