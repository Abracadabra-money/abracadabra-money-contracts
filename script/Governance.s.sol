// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {ERC1967Factory} from "solady/utils/ERC1967Factory.sol";
import {SpellTimelock} from "/governance/SpellTimelock.sol";

contract GovernanceScript is BaseScript {
    ERC1967Factory factory;

    // salts
    bytes32 timelockSalt;

    // Proxies
    address timelock;

    // Implementations
    address timelockImpl;

    function deploy() public {
        factory = ERC1967Factory(toolkit.getAddress(ChainId.All, "ERC1967Factory"));
        timelockSalt = generateERC1967FactorySalt(tx.origin, "Timelock-1");

        vm.startBroadcast();

        _deployImplementations();
        _deployProxies();

        vm.stopBroadcast();
    }

    function _deployFactory() internal {
        deployUsingCreate3("ERC1967Factory", keccak256(bytes("ERC1967Factory-2")), "ERC1967Factory.sol:ERC1967Factory", "");
    }

    function _deployProxies() internal {
        timelock = factory.deployDeterministicAndCall(
            timelockImpl,
            tx.origin,
            timelockSalt,
            abi.encodeCall(SpellTimelock.initialize, (2 days, new address[](0), new address[](0), tx.origin))
        );
    }

    function _deployImplementations() internal {
        // Timelock
        timelockImpl = deploy("SpellTimelock", "SpellTimelock.sol:SpellTimelock", "");
    }
}
