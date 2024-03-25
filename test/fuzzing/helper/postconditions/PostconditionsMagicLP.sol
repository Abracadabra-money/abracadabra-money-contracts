// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "../../properties/Properties.sol";
import "./PostconditionsBase.sol";

/**
 * @title PostconditionsMagicLP
 * @author 0xScourgedev
 * @notice Contains all postconditions for MagicLP
 */
abstract contract PostconditionsMagicLP is PostconditionsBase {
    function buySharesPostconditions(
        bool success,
        bytes memory returnData,
        address[] memory actorsToUpdate,
        address[] memory poolsToUpdate
    ) internal {
        if (success) {
            _after(actorsToUpdate, poolsToUpdate);
            onSuccessInvariantsGeneral(poolsToUpdate);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function correctRStatePostconditions(
        bool success,
        bytes memory returnData,
        address[] memory actorsToUpdate,
        address[] memory poolsToUpdate
    ) internal {
        if (success) {
            _after(actorsToUpdate, poolsToUpdate);
            onSuccessInvariantsGeneral(poolsToUpdate);
        } else {
            invariant_POOL_03();
            onFailInvariantsGeneral(returnData);
        }
    }

    function sellBasePostconditions(
        bool success,
        bytes memory returnData,
        address[] memory actorsToUpdate,
        address[] memory poolsToUpdate
    ) internal {
        if (success) {
            _after(actorsToUpdate, poolsToUpdate);
            onSuccessInvariantsGeneral(poolsToUpdate);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function sellQuotePostconditions(
        bool success,
        bytes memory returnData,
        address[] memory actorsToUpdate,
        address[] memory poolsToUpdate
    ) internal {
        if (success) {
            _after(actorsToUpdate, poolsToUpdate);
            onSuccessInvariantsGeneral(poolsToUpdate);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function sellSharesPostconditions(
        bool success,
        bytes memory returnData,
        address[] memory actorsToUpdate,
        address[] memory poolsToUpdate
    ) internal {
        if (success) {
            _after(actorsToUpdate, poolsToUpdate);
            onSuccessInvariantsGeneral(poolsToUpdate);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function syncPostconditions(
        bool success,
        bytes memory returnData,
        address[] memory actorsToUpdate,
        address[] memory poolsToUpdate
    ) internal {
        if (success) {
            _after(actorsToUpdate, poolsToUpdate);
            onSuccessInvariantsGeneral(poolsToUpdate);
        } else {
            invariant_POOL_02();
            onFailInvariantsGeneral(returnData);
        }
    }

    function transferPostconditions(
        bool success,
        bytes memory returnData,
        address[] memory actorsToUpdate,
        address[] memory poolsToUpdate
    ) internal {
        if (success) {
            _after(actorsToUpdate, poolsToUpdate);
            onSuccessInvariantsGeneral(poolsToUpdate);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }
}
