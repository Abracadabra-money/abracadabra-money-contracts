// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./FuzzSetup.sol";
import "./helper/preconditions/PreconditionsFactory.sol";
import "./helper/postconditions/PostconditionsFactory.sol";
import "./util/FunctionCalls.sol";

/**
 * @title FuzzFactory
 * @author 0xScourgedev
 * @notice Fuzz handlers for Factory
 */
contract FuzzFactory is PreconditionsFactory, PostconditionsFactory {
    function fuzz_create(uint8 baseToken_, uint8 quoteToken_, uint256 lpFeeRate_, uint256 i_, uint256 k_) public setCurrentActor {
        CreateParams memory params = createPreconditions(baseToken_, quoteToken_, lpFeeRate_, i_, k_);

        address[] memory actorsToUpdate = new address[](1);
        actorsToUpdate[0] = currentActor;

        address[] memory poolsToUpdate = new address[](1);

        _before(actorsToUpdate, poolsToUpdate);

        (bool success, bytes memory returnData) = _createCall(
            params.baseToken_,
            params.quoteToken_,
            params.lpFeeRate_,
            params.i_,
            params.k_
        );

        createPostconditions(success, returnData, actorsToUpdate, poolsToUpdate, params.baseToken_, params.quoteToken_);
    }
}
