// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/ERC20.sol";
import "BoringSolidity/libraries/BoringERC20.sol";

contract ExchangeRouterMock {
    using BoringERC20 for ERC20;
    ERC20 public tokenIn;
    ERC20 public tokenOut;

    constructor(ERC20 _tokenIn, ERC20 _tokenOut) {
        tokenIn = _tokenIn;
        tokenOut = _tokenOut;
    }

    function setTokens(ERC20 _tokenIn, ERC20 _tokenOut) external {
        tokenIn = _tokenIn;
        tokenOut = _tokenOut;
    }

    fallback() external {
        tokenIn.safeTransferFrom(msg.sender, address(this), tokenIn.balanceOf(msg.sender));
        tokenOut.safeTransfer(msg.sender, tokenOut.balanceOf(address(this)));
    }
}
