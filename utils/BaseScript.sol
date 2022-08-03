// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "./Constants.sol";
import "./Deploy.sol";

contract BaseScript is Script {
    Constants internal constants = new Constants();
    Deploy internal immutable deploy = new Deploy();
    bool internal testing;

    function setTesting(bool _testing) public {
        testing = _testing;
    }
}
