// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "BoringSolidity/ERC20.sol";
import "interfaces/ISolidlyPair.sol";
import "forge-std/console2.sol";

library SolidlyUtils {
    function simulateTrades(
        ISolidlyPair pair,
        ERC20 token,
        uint256 amount,
        uint256 count
    ) internal {
        while (count > 0 && token.balanceOf(address(this)) > 0) {
            uint256 amountOut = pair.getAmountOut(amount, address(token));
            token.transfer(address(pair), amount);

            if (address(token) == pair.token0()) {
                pair.swap(0, amountOut, address(this), "");
                token = ERC20(pair.token1());
            } else {
                pair.swap(amountOut, 0, address(this), "");
                token = ERC20(pair.token0());
            }

            amount = amountOut;
            count--;
        }
    }
}
