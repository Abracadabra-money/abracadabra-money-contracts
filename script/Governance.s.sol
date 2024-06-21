// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {ERC1967Factory} from "solady/utils/ERC1967Factory.sol";

contract GovernanceScript is BaseScript {
    bytes32 constant TIMELOCK_SALT = keccak256(bytes("Timelock-1"));
    bytes32 constant SPELL_GOVERNOR_SALT = keccak256(bytes("SpellGovernor-1"));

    function deploy() public {
        vm.startBroadcast();

        //deployUsingCreate3("ERC1967Factory", keccak256(bytes("ERC1967Factory-2")), "ERC1967Factory.sol:ERC1967Factory", "");
        address erc1967Factory = toolkit.getAddress(ChainId.All, "ERC1967Factory");
        
        //deployUsingCreate3("Timelock", TIMELOCK_SALT, "TimelockController.sol:TimelockController", abi.encode(72 hours, ));
        //deployUsingCreate3("SpellGovernor", SPELL_GOVERNOR_SALT, "SpellGovernor.sol:SpellGovernor", abi.encode(tx.origin));
        vm.stopBroadcast();
    }

    function _deployProxies() internal {
    
    }
}
