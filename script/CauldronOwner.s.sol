// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {BaseScript} from "utils/BaseScript.sol";
import {CauldronOwner} from "periphery/CauldronOwner.sol";
import {CauldronRegistry} from "periphery/CauldronRegistry.sol";

contract CauldronOwnerScript is BaseScript {
    function deploy() public returns (CauldronOwner cauldronOwner) {
        address safe = toolkit.getAddress(block.chainid, "safe.main");
        address mim = toolkit.getAddress(block.chainid, "mim");
        address registry = toolkit.getAddress(block.chainid, "cauldronRegistry");

        vm.startBroadcast();
        cauldronOwner = CauldronOwner(deploy("CauldronOwner", "CauldronOwner.sol:CauldronOwner", abi.encode(safe, mim, tx.origin)));

        if (cauldronOwner.registry() != CauldronRegistry(registry)) {
            cauldronOwner.setRegistry(CauldronRegistry(registry));
        }

        if (!testing()) {
            if (cauldronOwner.owner() == tx.origin) {
                if (!cauldronOwner.hasAnyRole(tx.origin, cauldronOwner.ROLE_OPERATOR())) {
                    cauldronOwner.grantRoles(tx.origin, cauldronOwner.ROLE_OPERATOR());
                }

                cauldronOwner.transferOwnership(safe);
            }
        }
        vm.stopBroadcast();
    }
}
