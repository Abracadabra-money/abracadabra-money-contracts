// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "BoringSolidity/interfaces/IERC20.sol";
import "src/DegenBox.sol";

contract Deploy {
    function deployDegenBox(address weth) public returns(DegenBox) {
        return new DegenBox(IERC20(weth));
    }

    function deployCauldron() public pure returns (address) {
        return address(0);
    }

    function deployUniswapLikeZeroExSwappers() public pure returns (address) {
        return address(0);
    }

    function deploySolidlyLikeVolatileZeroExSwappers() public pure returns (address) {
        return address(0);
    }

    function deployLPOracle() public pure returns (address) {
        return address(0);
    }
}
