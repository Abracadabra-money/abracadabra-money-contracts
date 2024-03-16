// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./PreconditionsBase.sol";

/**
 * @title PreconditionsRouter
 * @author 0xScourgedev
 * @notice Contains all preconditions for Router
 */
abstract contract PreconditionsRouter is PreconditionsBase {
    struct AddLiquidityParams {
        address lpAddr;
        uint256 baseInAmount;
        uint256 quoteInAmount;
        uint256 minimumShares;
    }

    struct AddLiquidityETHParams {
        address lpAddr;
        uint256 tokenInAmount;
        uint256 value;
        uint256 minimumShares;
    }

    struct AddLiquidityETHUnsafeParams {
        address lpAddr;
        uint256 tokenInAmount;
        uint256 value;
        uint256 minimumShares;
    }

    struct AddLiquidityUnsafeParams {
        address lpAddr;
        uint256 baseInAmount;
        uint256 quoteInAmount;
        uint256 minimumShares;
    }

    struct CreatePoolParams {
        address baseToken;
        address quoteToken;
        uint256 lpFeeRate;
        uint256 i;
        uint256 k;
        address to;
        uint256 baseInAmount;
        uint256 quoteInAmount;
    }

    struct CreatePoolETHParams {
        address token;
        bool useTokenAsQuote;
        uint256 lpFeeRate;
        uint256 i;
        uint256 k;
        address to;
        uint256 tokenInAmount;
        uint256 value;
    }

    struct RemoveLiquidityParams {
        address lpAddr;
        uint256 sharesIn;
        uint256 minimumBaseAmount;
        uint256 minimumQuoteAmount;
    }

    struct RemoveLiquidityETHParams {
        address lpAddr;
        uint256 sharesIn;
        uint256 minimumETHAmount;
        uint256 minimumTokenAmount;
    }

    struct PreviewAddLiquidityParams {
        address lpAddr;
        uint256 baseInAmount;
        uint256 quoteInAmount;
    }

    struct PreviewRemoveLiquidityParams {
        address lpAddr;
        uint256 sharesIn;
    }

    struct SellBaseETHForTokensParams {
        address lpAddr;
        uint256 minimumOut;
        uint256 value;
    }

    struct SellBaseTokensForETHParams {
        address lpAddr;
        uint256 amountIn;
        uint256 minimumOut;
    }

    struct SellBaseTokensForTokensParams {
        address lpAddr;
        uint256 amountIn;
        uint256 minimumOut;
    }

    struct SellQuoteETHForTokensParams {
        address lpAddr;
        uint256 minimumOut;
        uint256 value;
    }

    struct SellQuoteTokensForETHParams {
        address lpAddr;
        uint256 amountIn;
        uint256 minimumOut;
    }

    struct SellQuoteTokensForTokensParams {
        address lpAddr;
        uint256 amountIn;
        uint256 minimumOut;
    }

    struct SwapETHForTokensParams {
        address[] path;
        uint256 directions;
        uint256 minimumOut;
        uint256 value;
    }

    struct SwapTokensForETHParams {
        uint256 amountIn;
        address[] path;
        uint256 directions;
        uint256 minimumOut;
    }

    struct SwapTokensForTokensParams {
        uint256 amountIn;
        address[] path;
        uint256 directions;
        uint256 minimumOut;
    }

    function addLiquidityPreconditions(
        uint8 lp,
        uint256 baseInAmount,
        uint256 quoteInAmount,
        uint256 minimumShares
    ) internal returns (AddLiquidityParams memory) {
        require(allPools.length > 0, "There are no available pools");

        address lpAddr = address(allPools[lp % allPools.length]);

        baseInAmount = clampBetween(baseInAmount, 0, IERC20(MagicLP(lpAddr)._BASE_TOKEN_()).balanceOf(address(currentActor)));
        quoteInAmount = clampBetween(quoteInAmount, 0, IERC20(MagicLP(lpAddr)._QUOTE_TOKEN_()).balanceOf(address(currentActor)));

        return AddLiquidityParams(lpAddr, baseInAmount, quoteInAmount, minimumShares);
    }

    function addLiquidityETHPreconditions(
        uint8 lp,
        uint256 tokenInAmount,
        uint256 value,
        uint256 minimumShares
    ) internal returns (AddLiquidityETHParams memory) {
        require(availablePools[address(weth)].length > 0, "There are no available pools with WETH");

        address quoteToken = availablePools[address(weth)][lp % availablePools[address(weth)].length];
        address lpAddr = pools[address(weth)][quoteToken];

        value = clampBetween(value, 0, currentActor.balance);

        if (MagicLP(lpAddr)._BASE_TOKEN_() == address(weth)) {
            tokenInAmount = clampBetween(tokenInAmount, 0, IERC20(MagicLP(lpAddr)._QUOTE_TOKEN_()).balanceOf(address(currentActor)));
        } else {
            tokenInAmount = clampBetween(tokenInAmount, 0, IERC20(MagicLP(lpAddr)._BASE_TOKEN_()).balanceOf(address(currentActor)));
        }

        return AddLiquidityETHParams(lpAddr, tokenInAmount, value, minimumShares);
    }

    function addLiquidityETHUnsafePreconditions(
        uint8 lp,
        uint256 tokenInAmount,
        uint256 value,
        uint256 minimumShares
    ) internal returns (AddLiquidityETHUnsafeParams memory) {
        require(availablePools[address(weth)].length > 0, "There are no available pools with WETH");

        address quoteToken = availablePools[address(weth)][lp % availablePools[address(weth)].length];
        address lpAddr = pools[address(weth)][quoteToken];

        value = clampBetween(value, 0, currentActor.balance);

        if (MagicLP(lpAddr)._BASE_TOKEN_() == address(weth)) {
            tokenInAmount = clampBetween(tokenInAmount, 0, IERC20(MagicLP(lpAddr)._QUOTE_TOKEN_()).balanceOf(address(currentActor)));
        } else {
            tokenInAmount = clampBetween(tokenInAmount, 0, IERC20(MagicLP(lpAddr)._BASE_TOKEN_()).balanceOf(address(currentActor)));
        }

        return AddLiquidityETHUnsafeParams(lpAddr, tokenInAmount, value, minimumShares);
    }

    function addLiquidityUnsafePreconditions(
        uint8 lp,
        uint256 baseInAmount,
        uint256 quoteInAmount,
        uint256 minimumShares
    ) internal returns (AddLiquidityUnsafeParams memory) {
        require(allPools.length > 0, "There are no available pools");

        address lpAddr = address(allPools[lp % allPools.length]);

        baseInAmount = clampBetween(baseInAmount, 0, IERC20(MagicLP(lpAddr)._BASE_TOKEN_()).balanceOf(address(currentActor)));
        quoteInAmount = clampBetween(quoteInAmount, 0, IERC20(MagicLP(lpAddr)._QUOTE_TOKEN_()).balanceOf(address(currentActor)));

        return AddLiquidityUnsafeParams(lpAddr, baseInAmount, quoteInAmount, minimumShares);
    }

    function createPoolPreconditions(
        uint8 baseToken,
        uint8 quoteToken,
        uint256 lpFeeRate,
        uint256 i,
        uint256 k,
        uint256 baseInAmount,
        uint256 quoteInAmount
    ) internal returns (CreatePoolParams memory) {
        require(allPools.length < MAX_POOLS, "Maximum number of pools reached");

        address baseTokenAddr = address(tokens[baseToken % tokens.length]);
        address quoteTokenAddr = address(tokens[quoteToken % tokens.length]);
        if (baseTokenAddr == quoteTokenAddr) {
            quoteTokenAddr = address(tokens[(quoteToken + 1) % tokens.length]);
        }

        lpFeeRate = clampBetween(lpFeeRate, MIN_LP_FEE_RATE, MAX_LP_FEE_RATE);
        i = clampBetween(i, 1, MAX_I);
        k = clampBetween(k, 0, MAX_K);

        return CreatePoolParams(baseTokenAddr, quoteTokenAddr, lpFeeRate, i, k, currentActor, baseInAmount, quoteInAmount);
    }

    function createPoolETHPreconditions(
        uint8 token,
        bool useTokenAsQuote,
        uint256 lpFeeRate,
        uint256 i,
        uint256 k,
        uint256 tokenInAmount,
        uint256 value
    ) internal returns (CreatePoolETHParams memory) {
        require(allPools.length < MAX_POOLS, "Maximum number of pools reached");

        address tokenAddr = address(tokens[token % tokens.length]);
        if (tokenAddr == address(weth)) {
            tokenAddr = address(tokens[(token + 1) % tokens.length]);
        }
        lpFeeRate = clampBetween(lpFeeRate, MIN_LP_FEE_RATE, MAX_LP_FEE_RATE);
        i = clampBetween(i, 1, MAX_I);
        k = clampBetween(k, 0, MAX_K);
        tokenInAmount = clampBetween(tokenInAmount, 0, IERC20(tokenAddr).balanceOf(address(currentActor)));
        value = clampBetween(value, 0, currentActor.balance);
        return CreatePoolETHParams(tokenAddr, useTokenAsQuote, lpFeeRate, i, k, currentActor, tokenInAmount, value);
    }

    function removeLiquidityPreconditions(
        uint8 lp,
        uint256 sharesIn,
        uint256 minimumBaseAmount,
        uint256 minimumQuoteAmount
    ) internal returns (RemoveLiquidityParams memory) {
        require(allPools.length > 0, "There are no available pools");

        address lpAddr = address(allPools[lp % allPools.length]);

        sharesIn = clampBetween(sharesIn, 0, MagicLP(lpAddr).balanceOf(address(currentActor)));

        return RemoveLiquidityParams(lpAddr, sharesIn, minimumBaseAmount, minimumQuoteAmount);
    }

    function removeLiquidityETHPreconditions(
        uint8 lp,
        uint256 sharesIn,
        uint256 minimumETHAmount,
        uint256 minimumTokenAmount
    ) internal returns (RemoveLiquidityETHParams memory) {
        require(availablePools[address(weth)].length > 0, "There are no available pools with WETH");

        address quoteToken = availablePools[address(weth)][lp % availablePools[address(weth)].length];
        address lpAddr = pools[address(weth)][quoteToken];

        sharesIn = clampBetween(sharesIn, 0, MagicLP(lpAddr).balanceOf(address(currentActor)));

        return RemoveLiquidityETHParams(lpAddr, sharesIn, minimumETHAmount, minimumTokenAmount);
    }

    function previewAddLiquidityPreconditions(
        uint8 lp,
        uint256 baseInAmount,
        uint256 quoteInAmount
    ) internal returns (PreviewAddLiquidityParams memory) {
        require(allPools.length > 0, "There are no available pools");

        address lpAddr = address(allPools[lp % allPools.length]);

        baseInAmount = clampBetween(baseInAmount, 0, REASONABLE_PREVIEW_AMOUNT);
        quoteInAmount = clampBetween(quoteInAmount, 0, REASONABLE_PREVIEW_AMOUNT);

        return PreviewAddLiquidityParams(lpAddr, baseInAmount, quoteInAmount);
    }

    function previewRemoveLiquidityPreconditions(uint8 lp, uint256 sharesIn) internal returns (PreviewRemoveLiquidityParams memory) {
        require(allPools.length > 0, "There are no available pools");

        address lpAddr = address(allPools[lp % allPools.length]);

        sharesIn = clampBetween(sharesIn, 0, REASONABLE_PREVIEW_AMOUNT);

        return PreviewRemoveLiquidityParams(lpAddr, sharesIn);
    }

    function sellBaseETHForTokensPreconditions(
        uint8 lp,
        uint256 minimumOut,
        uint256 value
    ) internal returns (SellBaseETHForTokensParams memory) {
        require(availablePools[address(weth)].length > 0, "There are no available pools with WETH");

        address quoteToken = availablePools[address(weth)][lp % availablePools[address(weth)].length];
        address lpAddr = pools[address(weth)][quoteToken];

        require(MagicLP(lpAddr)._BASE_TOKEN_() == address(weth), "The base token of the pool is not WETH");

        value = clampBetween(value, 0, currentActor.balance);

        return SellBaseETHForTokensParams(lpAddr, minimumOut, value);
    }

    function sellBaseTokensForETHPreconditions(
        uint8 lp,
        uint256 amountIn,
        uint256 minimumOut
    ) internal returns (SellBaseTokensForETHParams memory) {
        require(availablePools[address(weth)].length > 0, "There are no available pools with WETH");

        address quoteToken = availablePools[address(weth)][lp % availablePools[address(weth)].length];
        address lpAddr = pools[address(weth)][quoteToken];

        require(MagicLP(lpAddr)._QUOTE_TOKEN_() == address(weth), "The quote token of the pool is not WETH");

        amountIn = clampBetween(amountIn, 0, IERC20(MagicLP(lpAddr)._BASE_TOKEN_()).balanceOf(address(currentActor)));

        vm.prank(currentActor);
        IERC20(MagicLP(lpAddr)._BASE_TOKEN_()).approve(address(router), amountIn);

        return SellBaseTokensForETHParams(lpAddr, amountIn, minimumOut);
    }

    function sellBaseTokensForTokensPreconditions(
        uint8 lp,
        uint256 amountIn,
        uint256 minimumOut
    ) internal returns (SellBaseTokensForTokensParams memory) {
        require(allPools.length > 0, "There are no available pools");

        address lpAddr = address(allPools[lp % allPools.length]);

        amountIn = clampBetween(amountIn, 0, IERC20(MagicLP(lpAddr)._BASE_TOKEN_()).balanceOf(address(currentActor)));

        vm.prank(currentActor);
        IERC20(MagicLP(lpAddr)._BASE_TOKEN_()).approve(address(router), amountIn);

        return SellBaseTokensForTokensParams(lpAddr, amountIn, minimumOut);
    }

    function sellQuoteETHForTokensPreconditions(
        uint8 lp,
        uint256 minimumOut,
        uint256 value
    ) internal returns (SellQuoteETHForTokensParams memory) {
        require(availablePools[address(weth)].length > 0, "There are no available pools with WETH");

        address quoteToken = availablePools[address(weth)][lp % availablePools[address(weth)].length];
        address lpAddr = pools[address(weth)][quoteToken];

        require(MagicLP(lpAddr)._QUOTE_TOKEN_() == address(weth), "The base token of the pool is not WETH");

        value = clampBetween(value, 0, currentActor.balance);

        return SellQuoteETHForTokensParams(lpAddr, minimumOut, value);
    }

    function sellQuoteTokensForETHPreconditions(
        uint8 lp,
        uint256 amountIn,
        uint256 minimumOut
    ) internal returns (SellQuoteTokensForETHParams memory) {
        require(availablePools[address(weth)].length > 0, "There are no available pools with WETH");

        address quoteToken = availablePools[address(weth)][lp % availablePools[address(weth)].length];
        address lpAddr = pools[address(weth)][quoteToken];

        require(MagicLP(lpAddr)._BASE_TOKEN_() == address(weth), "The quote token of the pool is not WETH");

        amountIn = clampBetween(amountIn, 0, IERC20(MagicLP(lpAddr)._BASE_TOKEN_()).balanceOf(address(currentActor)));

        vm.prank(currentActor);
        IERC20(MagicLP(lpAddr)._BASE_TOKEN_()).approve(address(router), amountIn);

        return SellQuoteTokensForETHParams(lpAddr, amountIn, minimumOut);
    }

    function sellQuoteTokensForTokensPreconditions(
        uint8 lp,
        uint256 amountIn,
        uint256 minimumOut
    ) internal returns (SellQuoteTokensForTokensParams memory) {
        require(allPools.length > 0, "There are no available pools");

        address lpAddr = address(allPools[lp % allPools.length]);

        amountIn = clampBetween(amountIn, 0, IERC20(MagicLP(lpAddr)._BASE_TOKEN_()).balanceOf(address(currentActor)));

        vm.prank(currentActor);
        IERC20(MagicLP(lpAddr)._QUOTE_TOKEN_()).approve(address(router), amountIn);

        return SellQuoteTokensForTokensParams(lpAddr, amountIn, minimumOut);
    }

    function swapETHForTokensPreconditions(
        uint8 entropy,
        uint8 pathLength,
        uint256 directions,
        uint256 minimumOut,
        uint256 value
    ) internal returns (SwapETHForTokensParams memory) {
        require(allPools.length > 0, "There are no available pools");

        address currentToken = address(weth);
        pathLength = uint8(clampBetween(pathLength, 1, MAX_PATH_LENGTH));
        address[] memory tempPath = new address[](pathLength);
        uint8 constructedPathLength = 0;

        for (uint8 i = 0; i < pathLength; i++) {
            address nextPool = fetchPoolForToken(entropy, currentToken);
            if (nextPool == address(0)) {
                break;
            }
            tempPath[i] = nextPool;
            if (currentToken == MagicLP(nextPool)._QUOTE_TOKEN_()) {
                currentToken = MagicLP(nextPool)._BASE_TOKEN_();
            } else {
                currentToken = MagicLP(nextPool)._QUOTE_TOKEN_();
            }
            constructedPathLength++;
        }
        require(constructedPathLength > 0, "No valid path constructed");

        address[] memory path = new address[](constructedPathLength);
        for (uint8 i = 0; i < constructedPathLength; i++) {
            path[i] = tempPath[i];
        }

        value = clampBetween(value, 0, currentActor.balance);

        return SwapETHForTokensParams(path, directions, minimumOut, value);
    }

    event Path(address[] path);

    function swapTokensForETHPreconditions(
        uint256 amountIn,
        uint8 entropy,
        uint8 pathLength,
        uint256 directions,
        uint256 minimumOut
    ) internal returns (SwapTokensForETHParams memory) {
        require(allPools.length > 0, "There are no available pools");

        address currentToken = address(weth);
        pathLength = uint8(clampBetween(pathLength, 1, MAX_PATH_LENGTH));
        address[] memory tempPath = new address[](pathLength);
        uint8 constructedPathLength = 0;

        for (uint8 i = pathLength - 1; i >= 0; i--) {
            address nextPool = fetchPoolForToken(entropy, currentToken);
            if (nextPool == address(0)) {
                break;
            }
            tempPath[i] = nextPool;
            if (currentToken == MagicLP(nextPool)._QUOTE_TOKEN_()) {
                currentToken = MagicLP(nextPool)._BASE_TOKEN_();
            } else {
                currentToken = MagicLP(nextPool)._QUOTE_TOKEN_();
            }
            constructedPathLength++;
        }
        require(constructedPathLength > 0, "No valid path constructed");

        address[] memory path = new address[](constructedPathLength);
        for (uint8 i = 0; i < constructedPathLength; i++) {
            path[i] = tempPath[i + (pathLength - constructedPathLength)];
        }

        if (directions & 1 == 0) {
            amountIn = clampBetween(amountIn, 0, IERC20(IMagicLP(path[0])._BASE_TOKEN_()).balanceOf(address(currentActor)));
            IERC20(IMagicLP(path[0])._BASE_TOKEN_()).approve(path[0], amountIn);
        } else {
            amountIn = clampBetween(amountIn, 0, IERC20(IMagicLP(path[0])._QUOTE_TOKEN_()).balanceOf(address(currentActor)));
            IERC20(IMagicLP(path[0])._QUOTE_TOKEN_()).approve(path[0], amountIn);
        }

        return SwapTokensForETHParams(amountIn, path, directions, minimumOut);
    }

    function swapTokensForTokensPreconditions(
        uint8 startingToken,
        uint256 amountIn,
        uint8 entropy,
        uint8 pathLength,
        uint256 directions,
        uint256 minimumOut
    ) internal returns (SwapTokensForTokensParams memory) {
        require(allPools.length > 0, "There are no available pools");

        address currentToken = address(tokens[startingToken % tokens.length]);
        pathLength = uint8(clampBetween(pathLength, 1, MAX_PATH_LENGTH));
        address[] memory tempPath = new address[](pathLength);
        uint8 constructedPathLength = 0;

        for (uint8 i = 0; i < pathLength; i++) {
            address nextPool = fetchPoolForToken(entropy, currentToken);
            if (nextPool == address(0)) {
                break;
            }
            tempPath[i] = nextPool;
            if (currentToken == MagicLP(nextPool)._QUOTE_TOKEN_()) {
                currentToken = MagicLP(nextPool)._BASE_TOKEN_();
            } else {
                currentToken = MagicLP(nextPool)._QUOTE_TOKEN_();
            }
            constructedPathLength++;
        }
        require(constructedPathLength > 0, "No valid path constructed");

        address[] memory path = new address[](constructedPathLength);
        for (uint8 i = 0; i < constructedPathLength; i++) {
            path[i] = tempPath[i];
        }

        if (directions & 1 == 0) {
            amountIn = clampBetween(amountIn, 0, IERC20(IMagicLP(path[0])._BASE_TOKEN_()).balanceOf(address(currentActor)));
            IERC20(IMagicLP(path[0])._BASE_TOKEN_()).approve(path[0], amountIn);
        } else {
            amountIn = clampBetween(amountIn, 0, IERC20(IMagicLP(path[0])._QUOTE_TOKEN_()).balanceOf(address(currentActor)));
            IERC20(IMagicLP(path[0])._QUOTE_TOKEN_()).approve(path[0], amountIn);
        }

        return SwapTokensForTokensParams(amountIn, path, directions, minimumOut);
    }

    function fetchPoolForToken(uint8 entropy, address token) internal returns (address) {
        uint8 index = uint8(uint256(keccak256(abi.encode(entropy))));
        index = uint8(clampBetween(index, 0, availablePools[token].length - 1));
        address quoteToken = availablePools[token][index];
        return pools[token][quoteToken];
    }
}
