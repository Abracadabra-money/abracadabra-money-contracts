// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "BoringSolidity/interfaces/IERC20.sol";
import "/DegenBox.sol";
import "interfaces/IBentoBoxV1.sol";

abstract contract DegenBoxScript {
    function deployDegenBox(address weth) public returns (IBentoBoxV1) {
        address degenBox = address(new DegenBox(IERC20(weth)));
        return IBentoBoxV1(degenBox);
    }
}
