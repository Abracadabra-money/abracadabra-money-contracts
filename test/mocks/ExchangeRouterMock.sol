// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/ERC20.sol";
import "BoringSolidity/libraries/BoringERC20.sol";
import {IBentoBoxV1} from "interfaces/IBentoBoxV1.sol";

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

    function swap(address to) public returns (uint256 amountOut) {
        amountOut = tokenOut.balanceOf(address(this));
        tokenIn.safeTransferFrom(msg.sender, address(this), tokenIn.balanceOf(msg.sender));
        tokenOut.safeTransfer(to, amountOut);
    }

    function swapFromDegenBoxAndDepositToDegenBox(IBentoBoxV1 box, address to) public returns (uint256 amountOut) {
        box.withdraw(tokenIn, address(this), address(this), 0, box.balanceOf(tokenIn, address(this)));

        amountOut = tokenOut.balanceOf(address(this));
        tokenOut.safeTransfer(address(box), amountOut);
        box.deposit(tokenOut, address(box), address(to), amountOut, 0);
    }

    function swapAndDepositToDegenBox(IBentoBoxV1 box, address to) public returns (uint256 amountOut) {
        amountOut = swap(address(box));
        box.deposit(tokenOut, address(box), address(to), amountOut, 0);
    }

    fallback() external {
        swap(msg.sender);
    }
}
