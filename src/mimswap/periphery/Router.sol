// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IWETH} from "interfaces/IWETH.sol";
import {IMagicLP} from "/mimswap/interfaces/IMagicLP.sol";

contract Router {
    using SafeTransferLib for address;

    error ErrExpired();
    error ErrZeroAddress();
    error ErrPathTooLong();
    error ErrEmptyPath();
    error ErrBadPath();
    error ErrTooHighSlippage(uint256 amountOut);
    error ErrInvalidBaseToken();
    error ErrInvalidQuoteToken();
    error ErrInTokenNotETH();
    error ErrOutTokenNotETH();

    IWETH public immutable weth;

    receive() external payable {}

    constructor(IWETH weth_) {
        if (address(weth_) == address(0)) {
            revert ErrZeroAddress();
        }

        weth = weth_;
    }

    modifier ensureDeadline(uint256 deadline) {
        if (block.timestamp > deadline) {
            revert ErrExpired();
        }
        _;
    }

    function swapTokensForTokens(
        uint256 amountIn,
        address[] calldata path,
        uint256 directions,
        uint256 minimumOut,
        uint256 deadline
    ) external ensureDeadline(deadline) returns (uint256 amountOut) {
        return _swapTokensForTokens(msg.sender, amountIn, path, directions, minimumOut);
    }

    function swapTokensForTokens(
        address to,
        uint256 amountIn,
        address[] calldata path,
        uint256 directions,
        uint256 minimumOut,
        uint256 deadline
    ) external ensureDeadline(deadline) returns (uint256 amountOut) {
        return _swapTokensForTokens(to, amountIn, path, directions, minimumOut);
    }

    function swapETHForTokens(
        address[] calldata path,
        uint256 directions,
        uint256 minimumOut,
        uint256 deadline
    ) external payable ensureDeadline(deadline) returns (uint256 amountOut) {
        return _swapETHForTokens(msg.sender, path, directions, minimumOut);
    }

    function swapETHForTokens(
        address to,
        address[] calldata path,
        uint256 directions,
        uint256 minimumOut,
        uint256 deadline
    ) external payable ensureDeadline(deadline) returns (uint256 amountOut) {
        return _swapETHForTokens(to, path, directions, minimumOut);
    }

    function swapTokensForETH(
        uint256 amountIn,
        address[] calldata path,
        uint256 directions,
        uint256 minimumOut,
        uint256 deadline
    ) external payable ensureDeadline(deadline) returns (uint256 amountOut) {
        return _swapTokensForETH(msg.sender, amountIn, path, directions, minimumOut);
    }

    function swapTokensForETH(
        address to,
        uint256 amountIn,
        address[] calldata path,
        uint256 directions,
        uint256 minimumOut,
        uint256 deadline
    ) external payable ensureDeadline(deadline) returns (uint256 amountOut) {
        return _swapTokensForETH(to, amountIn, path, directions, minimumOut);
    }

    function sellBaseTokensForTokens(
        address lp,
        uint256 amountIn,
        uint256 minimumOut,
        uint256 deadline
    ) external ensureDeadline(deadline) returns (uint256 amountOut) {
        return _sellBaseTokensForTokens(lp, msg.sender, amountIn, minimumOut);
    }

    function sellBaseTokensForTokens(
        address lp,
        address to,
        uint256 amountIn,
        uint256 minimumOut,
        uint256 deadline
    ) external ensureDeadline(deadline) returns (uint256 amountOut) {
        return _sellBaseTokensForTokens(lp, to, amountIn, minimumOut);
    }

    function sellBaseETHForTokens(
        address lp,
        uint256 minimumOut,
        uint256 deadline
    ) external payable ensureDeadline(deadline) returns (uint256 amountOut) {
        return _sellBaseETHForTokens(lp, msg.sender, minimumOut);
    }

    function sellBaseETHForTokens(
        address lp,
        address to,
        uint256 minimumOut,
        uint256 deadline
    ) external ensureDeadline(deadline) returns (uint256 amountOut) {
        return _sellBaseETHForTokens(lp, to, minimumOut);
    }

    function sellBaseTokensForETH(
        address lp,
        uint256 amountIn,
        uint256 minimumOut,
        uint256 deadline
    ) external ensureDeadline(deadline) returns (uint256 amountOut) {
        return _sellBaseTokensForETH(lp, msg.sender, amountIn, minimumOut);
    }

    function sellBaseTokensForETH(
        address lp,
        address to,
        uint256 amountIn,
        uint256 minimumOut,
        uint256 deadline
    ) external ensureDeadline(deadline) returns (uint256 amountOut) {
        return _sellBaseTokensForETH(lp, to, amountIn, minimumOut);
    }

    function sellQuoteTokensForTokens(
        address lp,
        uint256 amountIn,
        uint256 minimumOut,
        uint256 deadline
    ) external ensureDeadline(deadline) returns (uint256 amountOut) {
        return _sellQuoteTokensForTokens(lp, msg.sender, amountIn, minimumOut);
    }

    function sellQuoteTokensForTokens(
        address lp,
        address to,
        uint256 amountIn,
        uint256 minimumOut,
        uint256 deadline
    ) external ensureDeadline(deadline) returns (uint256 amountOut) {
        return _sellQuoteTokensForTokens(lp, to, amountIn, minimumOut);
    }

    function sellQuoteETHForTokens(
        address lp,
        uint256 minimumOut,
        uint256 deadline
    ) external payable ensureDeadline(deadline) returns (uint256 amountOut) {
        return _sellQuoteETHForTokens(lp, msg.sender, minimumOut);
    }

    function sellQuoteETHForTokens(
        address lp,
        address to,
        uint256 minimumOut,
        uint256 deadline
    ) external ensureDeadline(deadline) returns (uint256 amountOut) {
        return _sellQuoteETHForTokens(lp, to, minimumOut);
    }

    function sellQuoteTokensForETH(
        address lp,
        uint256 amountIn,
        uint256 minimumOut,
        uint256 deadline
    ) external ensureDeadline(deadline) returns (uint256 amountOut) {
        return _sellQuoteTokensForETH(lp, msg.sender, amountIn, minimumOut);
    }

    function sellQuoteTokensForETH(
        address lp,
        address to,
        uint256 amountIn,
        uint256 minimumOut,
        uint256 deadline
    ) external ensureDeadline(deadline) returns (uint256 amountOut) {
        return _sellQuoteTokensForETH(lp, to, amountIn, minimumOut);
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// INTERNALS
    //////////////////////////////////////////////////////////////////////////////////////

    function _swapTokensForTokens(
        address to,
        uint256 amountIn,
        address[] calldata path,
        uint256 directions,
        uint256 minimumOut
    ) internal returns (uint256 amountOut) {
        _validatePath(path);

        address firstLp = path[0];

        // Transfer to the first LP
        if (directions & 1 == 0) {
            IMagicLP(firstLp)._BASE_TOKEN_().safeTransferFrom(msg.sender, address(firstLp), amountIn);
        } else {
            IMagicLP(firstLp)._QUOTE_TOKEN_().safeTransferFrom(msg.sender, address(firstLp), amountIn);
        }

        return _swap(to, path, directions, minimumOut);
    }

    function _swapETHForTokens(
        address to,
        address[] calldata path,
        uint256 directions,
        uint256 minimumOut
    ) internal returns (uint256 amountOut) {
        _validatePath(path);

        address firstLp = path[0];
        address inToken;

        if (directions & 1 == 0) {
            inToken = IMagicLP(firstLp)._BASE_TOKEN_();
        } else {
            inToken = IMagicLP(firstLp)._QUOTE_TOKEN_();
        }

        // Transfer to the first LP
        if (inToken != address(weth)) {
            revert ErrInTokenNotETH();
        }

        weth.deposit{value: msg.value}();
        inToken.safeTransfer(address(firstLp), msg.value);

        return _swap(to, path, directions, minimumOut);
    }

    function _swapTokensForETH(
        address to,
        uint256 amountIn,
        address[] calldata path,
        uint256 directions,
        uint256 minimumOut
    ) internal returns (uint256 amountOut) {
        _validatePath(path);

        uint256 lastLpIndex = path.length - 1;
        address lastLp = path[lastLpIndex];
        address outToken;

        if ((directions >> lastLpIndex) & 1 == 0) {
            outToken = IMagicLP(lastLp)._QUOTE_TOKEN_();
        } else {
            outToken = IMagicLP(lastLp)._BASE_TOKEN_();
        }

        if (outToken != address(weth)) {
            revert ErrOutTokenNotETH();
        }

        address firstLp = path[0];

        // Transfer to the first LP
        if (directions & 1 == 0) {
            IMagicLP(firstLp)._BASE_TOKEN_().safeTransferFrom(msg.sender, firstLp, amountIn);
        } else {
            IMagicLP(firstLp)._QUOTE_TOKEN_().safeTransferFrom(msg.sender, firstLp, amountIn);
        }

        amountOut = _swap(address(this), path, directions, minimumOut);
        weth.withdraw(amountOut);

        to.safeTransferETH(amountOut);
    }

    function _swap(address to, address[] calldata path, uint256 directions, uint256 minimumOut) internal returns (uint256 amountOut) {
        uint256 iterations = path.length - 1; // Subtract by one as last swap is done separately

        for (uint256 i = 0; i < iterations; ) {
            if (directions & 1 == 0) {
                // Sell base
                IMagicLP(path[i]).sellBase(address(path[i + 1]));
            } else {
                // Sell quote
                IMagicLP(path[i]).sellQuote(address(path[i + 1]));
            }

            directions >>= 1;

            unchecked {
                ++i;
            }
        }

        if ((directions & 1 == 0)) {
            amountOut = IMagicLP(path[iterations]).sellBase(to);
        } else {
            amountOut = IMagicLP(path[iterations]).sellQuote(to);
        }

        if (amountOut < minimumOut) {
            revert ErrTooHighSlippage(amountOut);
        }
    }

    function _sellBaseTokensForTokens(address lp, address to, uint256 amountIn, uint256 minimumOut) internal returns (uint256 amountOut) {
        IMagicLP(lp)._BASE_TOKEN_().safeTransferFrom(msg.sender, lp, amountIn);
        return _sellBase(lp, to, minimumOut);
    }

    function _sellBaseETHForTokens(address lp, address to, uint256 minimumOut) internal returns (uint256 amountOut) {
        address baseToken = IMagicLP(lp)._BASE_TOKEN_();

        if (baseToken != address(weth)) {
            revert ErrInvalidBaseToken();
        }

        weth.deposit{value: msg.value}();
        baseToken.safeTransfer(lp, msg.value);
        return _sellBase(lp, to, minimumOut);
    }

    function _sellBaseTokensForETH(address lp, address to, uint256 amountIn, uint256 minimumOut) internal returns (uint256 amountOut) {
        if (IMagicLP(lp)._QUOTE_TOKEN_() != address(weth)) {
            revert ErrInvalidQuoteToken();
        }

        IMagicLP(lp)._BASE_TOKEN_().safeTransferFrom(msg.sender, lp, amountIn);
        amountOut = _sellBase(lp, address(this), minimumOut);
        weth.withdraw(amountOut);
        to.safeTransferETH(amountOut);
    }

    function _sellBase(address lp, address to, uint256 minimumOut) internal returns (uint256 amountOut) {
        amountOut = IMagicLP(lp).sellBase(to);
        if (amountOut < minimumOut) {
            revert ErrTooHighSlippage(amountOut);
        }
    }

    function _sellQuoteTokensForTokens(address lp, address to, uint256 amountIn, uint256 minimumOut) internal returns (uint256 amountOut) {
        IMagicLP(lp)._QUOTE_TOKEN_().safeTransferFrom(msg.sender, lp, amountIn);

        return _sellQuote(lp, to, minimumOut);
    }

    function _sellQuoteETHForTokens(address lp, address to, uint256 minimumOut) internal returns (uint256 amountOut) {
        address quoteToken = IMagicLP(lp)._QUOTE_TOKEN_();

        if (quoteToken != address(weth)) {
            revert ErrInvalidQuoteToken();
        }

        weth.deposit{value: msg.value}();
        quoteToken.safeTransfer(lp, msg.value);
        return _sellQuote(lp, to, minimumOut);
    }

    function _sellQuoteTokensForETH(address lp, address to, uint256 amountIn, uint256 minimumOut) internal returns (uint256 amountOut) {
        if (IMagicLP(lp)._BASE_TOKEN_() != address(weth)) {
            revert ErrInvalidBaseToken();
        }

        IMagicLP(lp)._QUOTE_TOKEN_().safeTransferFrom(msg.sender, lp, amountIn);
        amountOut = _sellQuote(lp, address(this), minimumOut);
        weth.withdraw(amountOut);
        to.safeTransferETH(amountOut);
    }

    function _sellQuote(address lp, address to, uint256 minimumOut) internal returns (uint256 amountOut) {
        amountOut = IMagicLP(lp).sellQuote(to);

        if (amountOut < minimumOut) {
            revert ErrTooHighSlippage(amountOut);
        }
    }

    function _validatePath(address[] calldata path) internal pure {
        uint256 pathLength = path.length;

        // Max 256 because of bits in directions
        if (pathLength > 256) {
            revert ErrPathTooLong();
        }
        if (pathLength <= 0) {
            revert ErrEmptyPath();
        }
    }
}
