// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {CREATE3} from "solmate/utils/CREATE3.sol";

contract Create3Factory {
    event LogDeployed(address deployed, address sender, bytes32 salt);

    function deploy(bytes32 salt, bytes memory bytecode, uint256 value) public returns (address deployed) {
        deployed = CREATE3.deploy(_getSalt(msg.sender, salt), bytecode, value);
        emit LogDeployed(deployed, msg.sender, salt);
    }

    function getDeployed(address account, bytes32 salt) public view returns (address) {
        return CREATE3.getDeployed(_getSalt(account, salt));
    }

    function _getSalt(address account, bytes32 salt) internal pure returns (bytes32) {
        return keccak256(abi.encode(account, salt));
    }
}
