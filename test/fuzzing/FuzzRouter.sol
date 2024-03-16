// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./FuzzSetup.sol";
import "./helper/preconditions/PreconditionsRouter.sol";
import "./helper/postconditions/PostconditionsRouter.sol";
import "./util/FunctionCalls.sol";

/**
 * @title FuzzRouter
 * @author 0xScourgedev
 * @notice Fuzz handlers for Router
 */
contract FuzzRouter is PreconditionsRouter, PostconditionsRouter {
    function fuzz_addLiquidity(uint8 lp, uint256 baseInAmount, uint256 quoteInAmount, uint256 minimumShares) public setCurrentActor {
        AddLiquidityParams memory params = addLiquidityPreconditions(lp, baseInAmount, quoteInAmount, minimumShares);

        address[] memory actorsToUpdate = new address[](1);
        actorsToUpdate[0] = currentActor;

        address[] memory poolsToUpdate = new address[](1);
        poolsToUpdate[0] = params.lpAddr;

        _before(actorsToUpdate, poolsToUpdate);

        (, , uint256 previewShares) = router.previewAddLiquidity(params.lpAddr, params.baseInAmount, params.quoteInAmount);

        (bool success, bytes memory returnData) = _addLiquidityCall(
            params.lpAddr,
            currentActor,
            params.baseInAmount,
            params.quoteInAmount,
            params.minimumShares,
            type(uint32).max
        );

        addLiquidityPostconditions(success, returnData, actorsToUpdate, poolsToUpdate, previewShares);
    }

    function fuzz_addLiquidityETH(uint8 lp, uint256 tokenInAmount, uint256 value, uint256 minimumShares) public setCurrentActor {
        AddLiquidityETHParams memory params = addLiquidityETHPreconditions(lp, tokenInAmount, value, minimumShares);

        address[] memory actorsToUpdate = new address[](1);
        actorsToUpdate[0] = currentActor;

        address[] memory poolsToUpdate = new address[](1);
        poolsToUpdate[0] = params.lpAddr;

        _before(actorsToUpdate, poolsToUpdate);

        address token = IMagicLP(params.lpAddr)._BASE_TOKEN_();
        uint256 previewShares;
        if (token == address(weth)) {
            (, , previewShares) = router.previewAddLiquidity(params.lpAddr, params.value, params.tokenInAmount);
        } else {
            (, , previewShares) = router.previewAddLiquidity(params.lpAddr, params.tokenInAmount, params.value);
        }

        (bool success, bytes memory returnData) = _addLiquidityETHCall(
            params.lpAddr,
            currentActor,
            currentActor,
            params.tokenInAmount,
            params.value,
            params.minimumShares,
            type(uint32).max
        );

        addLiquidityETHPostconditions(success, returnData, actorsToUpdate, poolsToUpdate, previewShares);
    }

    function fuzz_addLiquidityETHUnsafe(uint8 lp, uint256 tokenInAmount, uint256 value, uint256 minimumShares) public setCurrentActor {
        AddLiquidityETHUnsafeParams memory params = addLiquidityETHUnsafePreconditions(lp, tokenInAmount, value, minimumShares);

        address[] memory actorsToUpdate = new address[](1);
        actorsToUpdate[0] = currentActor;

        address[] memory poolsToUpdate = new address[](1);
        poolsToUpdate[0] = params.lpAddr;

        _before(actorsToUpdate, poolsToUpdate);

        address token = IMagicLP(params.lpAddr)._BASE_TOKEN_();
        uint256 previewShares;
        if (token == address(weth)) {
            (, , previewShares) = router.previewAddLiquidity(params.lpAddr, params.value, params.tokenInAmount);
        } else {
            (, , previewShares) = router.previewAddLiquidity(params.lpAddr, params.tokenInAmount, params.value);
        }

        (bool success, bytes memory returnData) = _addLiquidityETHUnsafeCall(
            params.lpAddr,
            currentActor,
            params.tokenInAmount,
            params.value,
            params.minimumShares,
            type(uint32).max
        );

        addLiquidityETHUnsafePostconditions(success, returnData, actorsToUpdate, poolsToUpdate, previewShares);
    }

    function fuzz_addLiquidityUnsafe(uint8 lp, uint256 baseInAmount, uint256 quoteInAmount, uint256 minimumShares) public setCurrentActor {
        AddLiquidityUnsafeParams memory params = addLiquidityUnsafePreconditions(lp, baseInAmount, quoteInAmount, minimumShares);

        address[] memory actorsToUpdate = new address[](1);
        actorsToUpdate[0] = currentActor;

        address[] memory poolsToUpdate = new address[](1);
        poolsToUpdate[0] = params.lpAddr;

        _before(actorsToUpdate, poolsToUpdate);

        (, , uint256 previewShares) = router.previewAddLiquidity(params.lpAddr, params.baseInAmount, params.quoteInAmount);

        (bool success, bytes memory returnData) = _addLiquidityUnsafeCall(
            params.lpAddr,
            currentActor,
            params.baseInAmount,
            params.quoteInAmount,
            params.minimumShares,
            type(uint32).max
        );

        addLiquidityUnsafePostconditions(success, returnData, actorsToUpdate, poolsToUpdate, previewShares);
    }

    function fuzz_createPool(
        uint8 baseToken,
        uint8 quoteToken,
        uint256 lpFeeRate,
        uint256 i,
        uint256 k,
        uint256 baseInAmount,
        uint256 quoteInAmount
    ) public setCurrentActor {
        CreatePoolParams memory params = createPoolPreconditions(baseToken, quoteToken, lpFeeRate, i, k, baseInAmount, quoteInAmount);

        address[] memory actorsToUpdate = new address[](1);
        actorsToUpdate[0] = currentActor;

        address[] memory poolsToUpdate = new address[](1);

        _before(actorsToUpdate, poolsToUpdate);

        (bool success, bytes memory returnData) = _createPoolCall(
            params.baseToken,
            params.quoteToken,
            params.lpFeeRate,
            params.i,
            params.k,
            currentActor,
            params.baseInAmount,
            params.quoteInAmount
        );

        createPoolPostconditions(success, returnData, actorsToUpdate, poolsToUpdate, params.baseToken, params.quoteToken);
    }

    function fuzz_createPoolETH(
        uint8 token,
        bool useTokenAsQuote,
        uint256 lpFeeRate,
        uint256 i,
        uint256 k,
        uint256 tokenInAmount,
        uint256 value
    ) public setCurrentActor {
        CreatePoolETHParams memory params = createPoolETHPreconditions(token, useTokenAsQuote, lpFeeRate, i, k, tokenInAmount, value);

        address[] memory actorsToUpdate = new address[](1);
        actorsToUpdate[0] = currentActor;

        address[] memory poolsToUpdate = new address[](1);

        _before(actorsToUpdate, poolsToUpdate);

        (bool success, bytes memory returnData) = _createPoolETHCall(
            params.token,
            params.useTokenAsQuote,
            params.lpFeeRate,
            params.i,
            params.k,
            currentActor,
            params.tokenInAmount,
            params.value
        );

        createPoolETHPostconditions(success, returnData, actorsToUpdate, poolsToUpdate, params.token);
    }

    function fuzz_removeLiquidity(
        uint8 lp,
        uint256 sharesIn,
        uint256 minimumBaseAmount,
        uint256 minimumQuoteAmount
    ) public setCurrentActor {
        RemoveLiquidityParams memory params = removeLiquidityPreconditions(lp, sharesIn, minimumBaseAmount, minimumQuoteAmount);

        address[] memory actorsToUpdate = new address[](1);
        actorsToUpdate[0] = currentActor;

        address[] memory poolsToUpdate = new address[](1);
        poolsToUpdate[0] = params.lpAddr;

        _before(actorsToUpdate, poolsToUpdate);

        (uint256 previewBase, uint256 previewQuote) = router.previewRemoveLiquidity(params.lpAddr, params.sharesIn);

        (bool success, bytes memory returnData) = _removeLiquidityCall(
            params.lpAddr,
            currentActor,
            params.sharesIn,
            params.minimumBaseAmount,
            params.minimumQuoteAmount,
            type(uint32).max
        );

        removeLiquidityPostconditions(success, returnData, actorsToUpdate, poolsToUpdate, params.sharesIn, previewBase, previewQuote);
    }

    function fuzz_removeLiquidityETH(
        uint8 lp,
        uint256 sharesIn,
        uint256 minimumETHAmount,
        uint256 minimumTokenAmount
    ) public setCurrentActor {
        RemoveLiquidityETHParams memory params = removeLiquidityETHPreconditions(lp, sharesIn, minimumETHAmount, minimumTokenAmount);

        address[] memory actorsToUpdate = new address[](1);
        actorsToUpdate[0] = currentActor;

        address[] memory poolsToUpdate = new address[](1);
        poolsToUpdate[0] = params.lpAddr;

        _before(actorsToUpdate, poolsToUpdate);

        (bool success, bytes memory returnData) = _removeLiquidityETHCall(
            params.lpAddr,
            currentActor,
            params.sharesIn,
            params.minimumETHAmount,
            params.minimumTokenAmount,
            type(uint32).max
        );

        removeLiquidityETHPostconditions(success, returnData, actorsToUpdate, poolsToUpdate, params.sharesIn);
    }

    function fuzz_previewAddLiquidity(uint8 lp, uint256 baseInAmount, uint256 quoteInAmount) public setCurrentActor {
        PreviewAddLiquidityParams memory params = previewAddLiquidityPreconditions(lp, baseInAmount, quoteInAmount);

        (bool success, bytes memory returnData) = _previewAddLiquidityCall(params.lpAddr, params.baseInAmount, params.quoteInAmount);

        previewAddLiquidityPostconditions(success, returnData);
    }

    function fuzz_previewRemoveLiquidity(uint8 lp, uint256 sharesIn) public setCurrentActor {
        PreviewRemoveLiquidityParams memory params = previewRemoveLiquidityPreconditions(lp, sharesIn);

        (bool success, bytes memory returnData) = _previewRemoveLiquidityCall(params.lpAddr, params.sharesIn);

        previewRemoveLiquidityPostconditions(success, returnData, params.lpAddr);
    }

    function fuzz_sellBaseETHForTokens(uint8 lp, uint256 minimumOut, uint256 value) public setCurrentActor {
        SellBaseETHForTokensParams memory params = sellBaseETHForTokensPreconditions(lp, minimumOut, value);

        address[] memory actorsToUpdate = new address[](1);
        actorsToUpdate[0] = currentActor;

        address[] memory poolsToUpdate = new address[](1);
        poolsToUpdate[0] = params.lpAddr;

        _before(actorsToUpdate, poolsToUpdate);

        (bool success, bytes memory returnData) = _sellBaseETHForTokensCall(
            params.lpAddr,
            currentActor,
            params.minimumOut,
            type(uint32).max,
            params.value
        );

        sellBaseETHForTokensPostconditions(success, returnData, actorsToUpdate, poolsToUpdate);
    }

    function fuzz_sellBaseTokensForETH(uint8 lp, uint256 amountIn, uint256 minimumOut) public setCurrentActor {
        SellBaseTokensForETHParams memory params = sellBaseTokensForETHPreconditions(lp, amountIn, minimumOut);

        address[] memory actorsToUpdate = new address[](1);
        actorsToUpdate[0] = currentActor;

        address[] memory poolsToUpdate = new address[](1);
        poolsToUpdate[0] = params.lpAddr;

        _before(actorsToUpdate, poolsToUpdate);

        (bool success, bytes memory returnData) = _sellBaseTokensForETHCall(
            params.lpAddr,
            currentActor,
            params.amountIn,
            params.minimumOut,
            type(uint32).max
        );

        sellBaseTokensForETHPostconditions(success, returnData, actorsToUpdate, poolsToUpdate);
    }

    function fuzz_sellBaseTokensForTokens(uint8 lp, uint256 amountIn, uint256 minimumOut) public setCurrentActor {
        SellBaseTokensForTokensParams memory params = sellBaseTokensForTokensPreconditions(lp, amountIn, minimumOut);

        address[] memory actorsToUpdate = new address[](1);
        actorsToUpdate[0] = currentActor;

        address[] memory poolsToUpdate = new address[](1);
        poolsToUpdate[0] = params.lpAddr;

        _before(actorsToUpdate, poolsToUpdate);

        (bool success, bytes memory returnData) = _sellBaseTokensForTokensCall(
            params.lpAddr,
            currentActor,
            params.amountIn,
            params.minimumOut,
            type(uint32).max
        );

        sellBaseTokensForTokensPostconditions(success, returnData, actorsToUpdate, poolsToUpdate);
    }

    function fuzz_sellQuoteETHForTokens(uint8 lp, uint256 minimumOut, uint256 value) public setCurrentActor {
        SellQuoteETHForTokensParams memory params = sellQuoteETHForTokensPreconditions(lp, minimumOut, value);

        address[] memory actorsToUpdate = new address[](1);
        actorsToUpdate[0] = currentActor;

        address[] memory poolsToUpdate = new address[](1);
        poolsToUpdate[0] = params.lpAddr;

        _before(actorsToUpdate, poolsToUpdate);

        (bool success, bytes memory returnData) = _sellQuoteETHForTokensCall(
            params.lpAddr,
            currentActor,
            params.minimumOut,
            type(uint32).max,
            params.value
        );

        sellQuoteETHForTokensPostconditions(success, returnData, actorsToUpdate, poolsToUpdate);
    }

    function fuzz_sellQuoteTokensForETH(uint8 lp, uint256 amountIn, uint256 minimumOut) public setCurrentActor {
        SellQuoteTokensForETHParams memory params = sellQuoteTokensForETHPreconditions(lp, amountIn, minimumOut);

        address[] memory actorsToUpdate = new address[](1);
        actorsToUpdate[0] = currentActor;

        address[] memory poolsToUpdate = new address[](1);
        poolsToUpdate[0] = params.lpAddr;

        _before(actorsToUpdate, poolsToUpdate);

        (bool success, bytes memory returnData) = _sellQuoteTokensForETHCall(
            params.lpAddr,
            currentActor,
            params.amountIn,
            params.minimumOut,
            type(uint32).max
        );

        sellQuoteTokensForETHPostconditions(success, returnData, actorsToUpdate, poolsToUpdate);
    }

    function fuzz_sellQuoteTokensForTokens(uint8 lp, uint256 amountIn, uint256 minimumOut) public setCurrentActor {
        SellQuoteTokensForTokensParams memory params = sellQuoteTokensForTokensPreconditions(lp, amountIn, minimumOut);

        address[] memory actorsToUpdate = new address[](1);
        actorsToUpdate[0] = currentActor;

        address[] memory poolsToUpdate = new address[](1);
        poolsToUpdate[0] = params.lpAddr;

        _before(actorsToUpdate, poolsToUpdate);

        (bool success, bytes memory returnData) = _sellQuoteTokensForTokensCall(
            params.lpAddr,
            currentActor,
            params.amountIn,
            params.minimumOut,
            type(uint32).max
        );

        sellQuoteTokensForTokensPostconditions(success, returnData, actorsToUpdate, poolsToUpdate);
    }

    function fuzz_swapETHForTokens(
        uint8 entropy,
        uint8 pathLength,
        uint256 directions,
        uint256 minimumOut,
        uint256 value
    ) public setCurrentActor {
        SwapETHForTokensParams memory params = swapETHForTokensPreconditions(entropy, pathLength, directions, minimumOut, value);

        address[] memory actorsToUpdate = new address[](1);
        actorsToUpdate[0] = currentActor;

        _before(actorsToUpdate, params.path);

        (bool success, bytes memory returnData) = _swapETHForTokensCall(
            currentActor,
            params.path,
            params.directions,
            params.minimumOut,
            type(uint32).max,
            params.value
        );

        swapETHForTokensPostconditions(success, returnData, actorsToUpdate, params.path, params.directions, params.minimumOut);
    }

    function fuzz_swapTokensForETH(
        uint256 amountIn,
        uint8 entropy,
        uint8 pathLength,
        uint256 directions,
        uint256 minimumOut
    ) public setCurrentActor {
        SwapTokensForETHParams memory params = swapTokensForETHPreconditions(amountIn, entropy, pathLength, directions, minimumOut);

        address[] memory actorsToUpdate = new address[](1);
        actorsToUpdate[0] = currentActor;

        _before(actorsToUpdate, params.path);

        (bool success, bytes memory returnData) = _swapTokensForETHCall(
            currentActor,
            params.amountIn,
            params.path,
            params.directions,
            params.minimumOut,
            type(uint32).max
        );

        swapTokensForETHPostconditions(success, returnData, actorsToUpdate, params.path, params.directions, params.minimumOut);
    }

    function fuzz_swapTokensForTokens(
        uint8 startingToken,
        uint256 amountIn,
        uint8 entropy,
        uint8 pathLength,
        uint256 directions,
        uint256 minimumOut
    ) public setCurrentActor {
        SwapTokensForTokensParams memory params = swapTokensForTokensPreconditions(
            startingToken,
            amountIn,
            entropy,
            pathLength,
            directions,
            minimumOut
        );

        address[] memory actorsToUpdate = new address[](1);
        actorsToUpdate[0] = currentActor;

        _before(actorsToUpdate, params.path);

        (bool success, bytes memory returnData) = _swapTokensForTokensCall(
            currentActor,
            params.amountIn,
            params.path,
            params.directions,
            params.minimumOut,
            type(uint32).max
        );

        swapTokensForTokensPostconditions(success, returnData, actorsToUpdate, params.path, params.directions, params.minimumOut);
    }
}
