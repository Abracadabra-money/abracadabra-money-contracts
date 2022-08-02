// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "./Common.sol";
import "./Deploy.sol";

contract BaseScript is Script, Common {
    bool internal testing;
    Deploy internal immutable deploy = new Deploy();

    function setTesting(bool _testing) public {
        testing = _testing;
    }
}
