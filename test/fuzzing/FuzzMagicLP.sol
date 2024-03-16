// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./FuzzSetup.sol";
import "./helper/preconditions/PreconditionsMagicLP.sol";
import "./helper/postconditions/PostconditionsMagicLP.sol";
import "./util/FunctionCalls.sol";

/**
 * @title FuzzMagicLP
 * @author 0xScourgedev
 * @notice Fuzz handlers for MagicLP
 */
contract FuzzMagicLP is PreconditionsMagicLP, PostconditionsMagicLP {
    function fuzz_buyShares(uint8 lp) public setCurrentActor {
        address lpAddr = buySharesPreconditions(lp);

        address[] memory actorsToUpdate = new address[](1);
        actorsToUpdate[0] = currentActor;

        address[] memory poolsToUpdate = new address[](1);
        poolsToUpdate[0] = lpAddr;

        _before(actorsToUpdate, poolsToUpdate);

        (bool success, bytes memory returnData) = _buySharesCall(lpAddr, currentActor);

        buySharesPostconditions(success, returnData, actorsToUpdate, poolsToUpdate);
    }

    function fuzz_correctRState(uint8 lp) public setCurrentActor {
        address lpAddr = correctRStatePreconditions(lp);

        address[] memory actorsToUpdate = new address[](1);
        actorsToUpdate[0] = currentActor;

        address[] memory poolsToUpdate = new address[](1);
        poolsToUpdate[0] = lpAddr;

        _before(actorsToUpdate, poolsToUpdate);

        (bool success, bytes memory returnData) = _correctRStateCall(lpAddr);

        correctRStatePostconditions(success, returnData, actorsToUpdate, poolsToUpdate);
    }

    function fuzz_sellBase(uint8 lp) public setCurrentActor {
        address lpAddr = sellBasePreconditions(lp);

        address[] memory actorsToUpdate = new address[](1);
        actorsToUpdate[0] = currentActor;

        address[] memory poolsToUpdate = new address[](1);
        poolsToUpdate[0] = lpAddr;

        _before(actorsToUpdate, poolsToUpdate);

        (bool success, bytes memory returnData) = _sellBaseCall(lpAddr, currentActor);

        sellBasePostconditions(success, returnData, actorsToUpdate, poolsToUpdate);
    }

    function fuzz_sellQuote(uint8 lp) public setCurrentActor {
        address lpAddr = sellQuotePreconditions(lp);

        address[] memory actorsToUpdate = new address[](1);
        actorsToUpdate[0] = currentActor;

        address[] memory poolsToUpdate = new address[](1);
        poolsToUpdate[0] = lpAddr;

        _before(actorsToUpdate, poolsToUpdate);

        (bool success, bytes memory returnData) = _sellQuoteCall(lpAddr, currentActor);

        sellQuotePostconditions(success, returnData, actorsToUpdate, poolsToUpdate);
    }

    function fuzz_sellShares(
        uint256 shareAmount,
        uint8 lp,
        uint256 baseMinAmount,
        uint256 quoteMinAmount,
        uint256 deadline
    ) public setCurrentActor {
        SellSharesParams memory params = sellSharesPreconditions(shareAmount, lp, baseMinAmount, quoteMinAmount, deadline);

        address[] memory actorsToUpdate = new address[](1);
        actorsToUpdate[0] = currentActor;

        address[] memory poolsToUpdate = new address[](1);
        poolsToUpdate[0] = params.lpAddr;

        _before(actorsToUpdate, poolsToUpdate);

        (bool success, bytes memory returnData) = _sellSharesCall(
            params.lpAddr,
            params.shareAmount,
            currentActor,
            params.baseMinAmount,
            params.quoteMinAmount,
            "",
            params.deadline
        );

        sellSharesPostconditions(success, returnData, actorsToUpdate, poolsToUpdate);
    }

    function fuzz_sync(uint8 lp) public setCurrentActor {
        address lpAddr = syncPreconditions(lp);

        address[] memory actorsToUpdate = new address[](1);
        actorsToUpdate[0] = currentActor;

        address[] memory poolsToUpdate = new address[](1);
        poolsToUpdate[0] = lpAddr;

        _before(actorsToUpdate, poolsToUpdate);

        (bool success, bytes memory returnData) = _syncCall(lpAddr);

        syncPostconditions(success, returnData, actorsToUpdate, poolsToUpdate);
    }

    function fuzz_transferSharesToLp(uint8 lp, uint256 amount) public setCurrentActor {
        TransferParams memory params = transferSharesToLpPreconditions(lp, amount);

        address[] memory actorsToUpdate = new address[](1);
        actorsToUpdate[0] = currentActor;

        address[] memory poolsToUpdate = new address[](1);
        poolsToUpdate[0] = params.lpAddr;

        _before(actorsToUpdate, poolsToUpdate);

        (bool success, bytes memory returnData) = _transferCall(params.lpAddr, params.lpAddr, params.amount);

        transferPostconditions(success, returnData, actorsToUpdate, poolsToUpdate);
    }

    function fuzz_transferTokensToLp(uint8 lp, bool transferQuote, uint256 amount) public setCurrentActor {
        TransferTokensToLpParams memory params = transferTokensToLpPreconditions(lp, transferQuote, amount);

        address[] memory actorsToUpdate = new address[](1);
        actorsToUpdate[0] = currentActor;

        address[] memory poolsToUpdate = new address[](1);
        poolsToUpdate[0] = params.lpAddr;

        _before(actorsToUpdate, poolsToUpdate);

        (bool success, bytes memory returnData) = _transferCall(params.token, params.lpAddr, params.amount);

        transferPostconditions(success, returnData, actorsToUpdate, poolsToUpdate);
    }
}
