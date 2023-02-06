// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "utils/BaseTest.sol";
import "utils/CauldronDeployLib.sol";

/// @dev A Script to run any kind of quick test
contract Playground is BaseTest {
    function test() public {
       console2.log(CauldronLib.getInterestPerSecond(600));
    }
}
