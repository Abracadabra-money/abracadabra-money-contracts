// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.0;

library MathLib {
    function max(uint256 a, uint256 b) public pure returns (uint256) {
        return a > b ? a : b;
    }

    function min(uint256 a, uint256 b) public pure returns (uint256) {
        return a > b ? b : a;
    }
}