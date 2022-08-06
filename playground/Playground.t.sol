// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "utils/BaseTest.sol";

contract TestContract {
    function example1() public returns (uint256) {
        for (uint256 i = 0; i < 100; i++) {}

        return 1;
    }

    function example2() public returns (uint256) {
        for (uint256 i = 0; i < 100; ) {
            unchecked {
                ++i;
            }
        }

        return 2;
    }
}

/// @dev A Script to run any kind of quick test
contract Playground is BaseTest {
    function test() public {
        TestContract t = new TestContract();
        uint256 g1 = t.example1();
        console.log(g1);
        uint256 g2 = t.example2();
        console.log(g2);

        assertGt(g2, g1);
    }
}
