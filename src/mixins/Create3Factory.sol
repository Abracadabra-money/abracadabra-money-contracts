// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "solmate/utils/CREATE3.sol";

contract Create3Factory {
    constructor() {}

    function deploy(bytes32 salt, bytes memory bytecode, uint256 value) public returns (address) {
        bytes32 deploySalt = keccak256(abi.encode(msg.sender, salt));
        return CREATE3.deploy(deploySalt, bytecode, value);
    }

    function getDeployed(bytes32 salt) public view returns (address) {
        bytes32 deploySalt = keccak256(abi.encode(msg.sender, salt));
        return CREATE3.getDeployed(deploySalt);
    }
}
