// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "fuzzlib/FuzzBase.sol";

import "../helper/FuzzStorageVariables.sol";

/**
 * @title FunctionCalls
 * @author 0xScourgedev
 * @notice Contains the function calls for all of the handlers
 */
abstract contract FunctionCalls is FuzzBase, FuzzStorageVariables {
    event CreateCall(address baseToken_, address quoteToken_, uint256 lpFeeRate_, uint256 i_, uint256 k_);
    event BuySharesCall(address to);
    event CorrectRStateCall();
    event SellBaseCall(address to);
    event SellQuoteCall(address to);
    event SellSharesCall(uint256 shareAmount, address to, uint256 baseMinAmount, uint256 quoteMinAmount, bytes data, uint256 deadline);
    event SyncCall();
    event TransferCall(address to, uint256 amount);
    event AddLiquidityCall(address lp, address to, uint256 baseInAmount, uint256 quoteInAmount, uint256 minimumShares, uint256 deadline);
    event AddLiquidityETHCall(
        address lp,
        address to,
        address refundTo,
        uint256 tokenInAmount,
        uint256 value,
        uint256 minimumShares,
        uint256 deadline
    );
    event AddLiquidityETHUnsafeCall(address lp, address to, uint256 tokenInAmount, uint256 value, uint256 minimumShares, uint256 deadline);
    event AddLiquidityUnsafeCall(
        address lp,
        address to,
        uint256 baseInAmount,
        uint256 quoteInAmount,
        uint256 minimumShares,
        uint256 deadline
    );
    event CreatePoolCall(
        address baseToken,
        address quoteToken,
        uint256 lpFeeRate,
        uint256 i,
        uint256 k,
        address to,
        uint256 baseInAmount,
        uint256 quoteInAmount
    );
    event CreatePoolETHCall(
        address token,
        bool useTokenAsQuote,
        uint256 lpFeeRate,
        uint256 i,
        uint256 k,
        address to,
        uint256 tokenInAmount
    );
    event RemoveLiquidityCall(
        address lp,
        address to,
        uint256 sharesIn,
        uint256 minimumBaseAmount,
        uint256 minimumQuoteAmount,
        uint256 deadline
    );
    event RemoveLiquidityETHCall(
        address lp,
        address to,
        uint256 sharesIn,
        uint256 minimumETHAmount,
        uint256 minimumTokenAmount,
        uint256 deadline
    );
    event PreviewAddLiquidityCall(address lp, uint256 baseInAmount, uint256 quoteInAmount);
    event PreviewRemoveLiquidityCall(address lp, uint256 sharesIn);
    event SellBaseETHForTokensCall(address lp, address to, uint256 minimumOut, uint256 deadline);
    event SellBaseTokensForETHCall(address lp, address to, uint256 amountIn, uint256 minimumOut, uint256 deadline);
    event SellBaseTokensForTokensCall(address lp, address to, uint256 amountIn, uint256 minimumOut, uint256 deadline);
    event SellQuoteETHForTokensCall(address lp, address to, uint256 minimumOut, uint256 deadline);
    event SellQuoteTokensForETHCall(address lp, address to, uint256 amountIn, uint256 minimumOut, uint256 deadline);
    event SellQuoteTokensForTokensCall(address lp, address to, uint256 amountIn, uint256 minimumOut, uint256 deadline);
    event SwapETHForTokensCall(address to, address[] path, uint256 directions, uint256 minimumOut, uint256 deadline);
    event SwapTokensForETHCall(address to, uint256 amountIn, address[] path, uint256 directions, uint256 minimumOut, uint256 deadline);
    event SwapTokensForTokensCall(address to, uint256 amountIn, address[] path, uint256 directions, uint256 minimumOut, uint256 deadline);

    function _createCall(
        address baseToken_,
        address quoteToken_,
        uint256 lpFeeRate_,
        uint256 i_,
        uint256 k_
    ) internal returns (bool success, bytes memory returnData) {
        emit CreateCall(baseToken_, quoteToken_, lpFeeRate_, i_, k_);

        vm.prank(currentActor);
        (success, returnData) = address(factory).call{gas: 1000000}(
            abi.encodeWithSelector(factory.create.selector, baseToken_, quoteToken_, lpFeeRate_, i_, k_, false)
        );
    }

    function _buySharesCall(address pool, address to) internal returns (bool success, bytes memory returnData) {
        emit BuySharesCall(to);

        vm.prank(currentActor);
        (success, returnData) = address(pool).call{gas: 1000000}(abi.encodeWithSelector(marketImpl.buyShares.selector, to));
    }

    function _correctRStateCall(address pool) internal returns (bool success, bytes memory returnData) {
        emit CorrectRStateCall();

        vm.prank(currentActor);
        (success, returnData) = address(pool).call{gas: 1000000}(abi.encodeWithSelector(marketImpl.correctRState.selector));
    }

    function _sellBaseCall(address pool, address to) internal returns (bool success, bytes memory returnData) {
        emit SellBaseCall(to);

        vm.prank(currentActor);
        (success, returnData) = address(pool).call{gas: 1000000}(abi.encodeWithSelector(marketImpl.sellBase.selector, to));
    }

    function _sellQuoteCall(address pool, address to) internal returns (bool success, bytes memory returnData) {
        emit SellQuoteCall(to);

        vm.prank(currentActor);
        (success, returnData) = address(pool).call{gas: 1000000}(abi.encodeWithSelector(marketImpl.sellQuote.selector, to));
    }

    function _sellSharesCall(
        address pool,
        uint256 shareAmount,
        address to,
        uint256 baseMinAmount,
        uint256 quoteMinAmount,
        bytes memory data,
        uint256 deadline
    ) internal returns (bool success, bytes memory returnData) {
        emit SellSharesCall(shareAmount, to, baseMinAmount, quoteMinAmount, data, deadline);

        vm.prank(currentActor);
        (success, returnData) = address(pool).call{gas: 1000000}(
            abi.encodeWithSelector(marketImpl.sellShares.selector, shareAmount, to, baseMinAmount, quoteMinAmount, data, deadline)
        );
    }

    function _syncCall(address pool) internal returns (bool success, bytes memory returnData) {
        emit SyncCall();

        vm.prank(currentActor);
        (success, returnData) = address(pool).call{gas: 1000000}(abi.encodeWithSelector(marketImpl.sync.selector));
    }

    function _transferCall(address token, address to, uint256 amount) internal returns (bool success, bytes memory returnData) {
        emit TransferCall(to, amount);

        vm.prank(currentActor);
        (success, returnData) = address(token).call{gas: 1000000}(abi.encodeWithSelector(marketImpl.transfer.selector, to, amount));
    }

    function _addLiquidityCall(
        address lp,
        address to,
        uint256 baseInAmount,
        uint256 quoteInAmount,
        uint256 minimumShares,
        uint256 deadline
    ) internal returns (bool success, bytes memory returnData) {
        emit AddLiquidityCall(lp, to, baseInAmount, quoteInAmount, minimumShares, deadline);

        vm.prank(currentActor);
        (success, returnData) = address(router).call{gas: 1000000}(
            abi.encodeWithSelector(router.addLiquidity.selector, lp, to, baseInAmount, quoteInAmount, minimumShares, deadline)
        );
    }

    function _addLiquidityETHCall(
        address lp,
        address to,
        address refundTo,
        uint256 tokenInAmount,
        uint256 value,
        uint256 minimumShares,
        uint256 deadline
    ) internal returns (bool success, bytes memory returnData) {
        emit AddLiquidityETHCall(lp, to, refundTo, tokenInAmount, value, minimumShares, deadline);

        vm.prank(currentActor);
        (success, returnData) = address(router).call{value: value, gas: 1000000}(
            abi.encodeWithSelector(router.addLiquidityETH.selector, lp, to, refundTo, tokenInAmount, minimumShares, deadline)
        );
    }

    function _addLiquidityETHUnsafeCall(
        address lp,
        address to,
        uint256 tokenInAmount,
        uint256 value,
        uint256 minimumShares,
        uint256 deadline
    ) internal returns (bool success, bytes memory returnData) {
        emit AddLiquidityETHUnsafeCall(lp, to, tokenInAmount, value, minimumShares, deadline);

        vm.prank(currentActor);
        (success, returnData) = address(router).call{value: value, gas: 1000000}(
            abi.encodeWithSelector(router.addLiquidityETHUnsafe.selector, lp, to, tokenInAmount, minimumShares, deadline)
        );
    }

    function _addLiquidityUnsafeCall(
        address lp,
        address to,
        uint256 baseInAmount,
        uint256 quoteInAmount,
        uint256 minimumShares,
        uint256 deadline
    ) internal returns (bool success, bytes memory returnData) {
        emit AddLiquidityUnsafeCall(lp, to, baseInAmount, quoteInAmount, minimumShares, deadline);

        vm.prank(currentActor);
        (success, returnData) = address(router).call{gas: 1000000}(
            abi.encodeWithSelector(router.addLiquidityUnsafe.selector, lp, to, baseInAmount, quoteInAmount, minimumShares, deadline)
        );
    }

    function _createPoolCall(
        address baseToken,
        address quoteToken,
        uint256 lpFeeRate,
        uint256 i,
        uint256 k,
        address to,
        uint256 baseInAmount,
        uint256 quoteInAmount
    ) internal returns (bool success, bytes memory returnData) {
        emit CreatePoolCall(baseToken, quoteToken, lpFeeRate, i, k, to, baseInAmount, quoteInAmount);

        vm.prank(currentActor);
        (success, returnData) = address(router).call{gas: 1000000}(
            abi.encodeWithSelector(
                router.createPool.selector,
                baseToken,
                quoteToken,
                lpFeeRate,
                i,
                k,
                to,
                baseInAmount,
                quoteInAmount,
                false
            )
        );
    }

    function _createPoolETHCall(
        address token,
        bool useTokenAsQuote,
        uint256 lpFeeRate,
        uint256 i,
        uint256 k,
        address to,
        uint256 tokenInAmount,
        uint256 value
    ) internal returns (bool success, bytes memory returnData) {
        emit CreatePoolETHCall(token, useTokenAsQuote, lpFeeRate, i, k, to, tokenInAmount);

        vm.prank(currentActor);
        (success, returnData) = address(router).call{value: value, gas: 1000000}(
            abi.encodeWithSelector(router.createPoolETH.selector, token, useTokenAsQuote, lpFeeRate, i, k, to, tokenInAmount, false)
        );
    }

    function _removeLiquidityCall(
        address lp,
        address to,
        uint256 sharesIn,
        uint256 minimumBaseAmount,
        uint256 minimumQuoteAmount,
        uint256 deadline
    ) internal returns (bool success, bytes memory returnData) {
        emit RemoveLiquidityCall(lp, to, sharesIn, minimumBaseAmount, minimumQuoteAmount, deadline);

        vm.prank(currentActor);
        (success, returnData) = address(lp).call{gas: 1000000}(
            abi.encodeWithSelector(marketImpl.approve.selector, address(router), sharesIn)
        );

        vm.prank(currentActor);
        (success, returnData) = address(router).call{gas: 1000000}(
            abi.encodeWithSelector(router.removeLiquidity.selector, lp, to, sharesIn, minimumBaseAmount, minimumQuoteAmount, deadline)
        );
    }

    function _removeLiquidityETHCall(
        address lp,
        address to,
        uint256 sharesIn,
        uint256 minimumETHAmount,
        uint256 minimumTokenAmount,
        uint256 deadline
    ) internal returns (bool success, bytes memory returnData) {
        emit RemoveLiquidityETHCall(lp, to, sharesIn, minimumETHAmount, minimumTokenAmount, deadline);

        vm.prank(currentActor);
        (success, returnData) = address(lp).call{gas: 1000000}(
            abi.encodeWithSelector(marketImpl.approve.selector, address(router), sharesIn)
        );

        vm.prank(currentActor);
        (success, returnData) = address(router).call{gas: 1000000}(
            abi.encodeWithSelector(router.removeLiquidityETH.selector, lp, to, sharesIn, minimumETHAmount, minimumTokenAmount, deadline)
        );
    }

    function _previewAddLiquidityCall(
        address lp,
        uint256 baseInAmount,
        uint256 quoteInAmount
    ) internal returns (bool success, bytes memory returnData) {
        emit PreviewAddLiquidityCall(lp, baseInAmount, quoteInAmount);

        (success, returnData) = address(router).staticcall(
            abi.encodeWithSelector(router.previewAddLiquidity.selector, lp, baseInAmount, quoteInAmount)
        );
    }

    function _previewRemoveLiquidityCall(address lp, uint256 sharesIn) internal returns (bool success, bytes memory returnData) {
        emit PreviewRemoveLiquidityCall(lp, sharesIn);

        (success, returnData) = address(router).staticcall(abi.encodeWithSelector(router.previewRemoveLiquidity.selector, lp, sharesIn));
    }

    function _sellBaseETHForTokensCall(
        address lp,
        address to,
        uint256 minimumOut,
        uint256 deadline,
        uint256 value
    ) internal returns (bool success, bytes memory returnData) {
        emit SellBaseETHForTokensCall(lp, to, minimumOut, deadline);

        vm.prank(currentActor);
        (success, returnData) = address(router).call{value: value, gas: 1000000}(
            abi.encodeWithSelector(router.sellBaseETHForTokens.selector, lp, to, minimumOut, deadline)
        );
    }

    function _sellBaseTokensForETHCall(
        address lp,
        address to,
        uint256 amountIn,
        uint256 minimumOut,
        uint256 deadline
    ) internal returns (bool success, bytes memory returnData) {
        emit SellBaseTokensForETHCall(lp, to, amountIn, minimumOut, deadline);

        vm.prank(currentActor);
        (success, returnData) = address(router).call{gas: 1000000}(
            abi.encodeWithSelector(router.sellBaseTokensForETH.selector, lp, to, amountIn, minimumOut, deadline)
        );
    }

    function _sellBaseTokensForTokensCall(
        address lp,
        address to,
        uint256 amountIn,
        uint256 minimumOut,
        uint256 deadline
    ) internal returns (bool success, bytes memory returnData) {
        emit SellBaseTokensForTokensCall(lp, to, amountIn, minimumOut, deadline);

        vm.prank(currentActor);
        (success, returnData) = address(router).call{gas: 1000000}(
            abi.encodeWithSelector(router.sellBaseTokensForTokens.selector, lp, to, amountIn, minimumOut, deadline)
        );
    }

    function _sellQuoteETHForTokensCall(
        address lp,
        address to,
        uint256 minimumOut,
        uint256 deadline,
        uint256 value
    ) internal returns (bool success, bytes memory returnData) {
        emit SellQuoteETHForTokensCall(lp, to, minimumOut, deadline);

        vm.prank(currentActor);
        (success, returnData) = address(router).call{value: value, gas: 1000000}(
            abi.encodeWithSelector(router.sellQuoteETHForTokens.selector, lp, to, minimumOut, deadline)
        );
    }

    function _sellQuoteTokensForETHCall(
        address lp,
        address to,
        uint256 amountIn,
        uint256 minimumOut,
        uint256 deadline
    ) internal returns (bool success, bytes memory returnData) {
        emit SellQuoteTokensForETHCall(lp, to, amountIn, minimumOut, deadline);

        vm.prank(currentActor);
        (success, returnData) = address(router).call{gas: 1000000}(
            abi.encodeWithSelector(router.sellQuoteTokensForETH.selector, lp, to, amountIn, minimumOut, deadline)
        );
    }

    function _sellQuoteTokensForTokensCall(
        address lp,
        address to,
        uint256 amountIn,
        uint256 minimumOut,
        uint256 deadline
    ) internal returns (bool success, bytes memory returnData) {
        emit SellQuoteTokensForTokensCall(lp, to, amountIn, minimumOut, deadline);

        vm.prank(currentActor);
        (success, returnData) = address(router).call{gas: 1000000}(
            abi.encodeWithSelector(router.sellQuoteTokensForTokens.selector, lp, to, amountIn, minimumOut, deadline)
        );
    }

    function _swapETHForTokensCall(
        address to,
        address[] memory path,
        uint256 directions,
        uint256 minimumOut,
        uint256 deadline,
        uint256 value
    ) internal returns (bool success, bytes memory returnData) {
        emit SwapETHForTokensCall(to, path, directions, minimumOut, deadline);

        vm.prank(currentActor);
        (success, returnData) = address(router).call{value: value, gas: 1000000}(
            abi.encodeWithSelector(router.swapETHForTokens.selector, to, path, directions, minimumOut, deadline)
        );
    }

    function _swapTokensForETHCall(
        address to,
        uint256 amountIn,
        address[] memory path,
        uint256 directions,
        uint256 minimumOut,
        uint256 deadline
    ) internal returns (bool success, bytes memory returnData) {
        emit SwapTokensForETHCall(to, amountIn, path, directions, minimumOut, deadline);

        vm.prank(currentActor);
        (success, returnData) = address(router).call{gas: 1000000}(
            abi.encodeWithSelector(router.swapTokensForETH.selector, to, amountIn, path, directions, minimumOut, deadline)
        );
    }

    function _swapTokensForTokensCall(
        address to,
        uint256 amountIn,
        address[] memory path,
        uint256 directions,
        uint256 minimumOut,
        uint256 deadline
    ) internal returns (bool success, bytes memory returnData) {
        emit SwapTokensForTokensCall(to, amountIn, path, directions, minimumOut, deadline);

        vm.prank(currentActor);
        (success, returnData) = address(router).call{gas: 1000000}(
            abi.encodeWithSelector(router.swapTokensForTokens.selector, to, amountIn, path, directions, minimumOut, deadline)
        );
    }
}
