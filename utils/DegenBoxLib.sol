// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "BoringSolidity/interfaces/IERC20.sol";
import "/DegenBox.sol";
import "interfaces/IBentoBoxV1.sol";

library DegenBoxLib {
    function deployDegenBox(IERC20 weth) internal returns (IBentoBoxV1) {
        return IBentoBoxV1(address(new DegenBox(weth)));
    }
}
