// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "solmate/utils/CREATE3.sol";

contract Create3Factory {
    constructor() {}

    function deploy(bytes32 salt, bytes memory bytecode, uint256 value) public returns (address) {
        return CREATE3.deploy(salt, bytecode, value);
    }
}
