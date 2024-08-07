// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {LibClone} from "@solady/utils/LibClone.sol";
import {MagicKodiakVault} from "/tokens/MagicKodiakVault.sol";

contract MagicKodiakScript is BaseScript {
    bytes32 constant VAULT_SALT = keccak256("MagicKodiakVault");

    function deploy() public returns (MagicKodiakVault instance) {
        vm.startBroadcast();

        address magicKodiak = deploy(
            "MagicKodiakVault_BeraHoneyImpl",
            "MagicKodiakVault.sol:MagicKodiakVault",
            abi.encode(toolkit.getAddress("kodiak.pools.berahoney"))
        );

        instance = MagicKodiakVault(deployUsingCreate3("MagicKodiakVault_BeraHoney", VAULT_SALT, LibClone.initCodeERC1967(magicKodiak)));
        instance.initialize(tx.origin, toolkit.getAddress("kodiak.staking"));

        if (instance.owner() != tx.origin) {
            revert("owner should be the deployer");
        }

        instance.setOperator(tx.origin, true);
        vm.stopBroadcast();
    }
}
