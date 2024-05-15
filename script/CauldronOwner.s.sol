// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {BaseScript} from "utils/BaseScript.sol";
import {CauldronOwner} from "periphery/CauldronOwner.sol";

contract CauldronOwnerScript is BaseScript {
    function deploy() public {
        address safe = toolkit.getAddress(block.chainid, "safe.ops");
        address mim = toolkit.getAddress(block.chainid, "mim");

        vm.startBroadcast();
        CauldronOwner cauldronOwner = CauldronOwner(deploy("CauldronOwner", "CauldronOwner.sol:CauldronOwner", abi.encode(safe, mim)));

        if (!testing()) {
            if (cauldronOwner.owner() == tx.origin) {
                cauldronOwner.grantRoles(tx.origin, cauldronOwner.ROLE_OPERATOR());
                cauldronOwner.grantRoles(0x8764F421AB0C682b4Ba1d7e269C09187c1EfbFAF, cauldronOwner.ROLE_CHANGE_BORROW_LIMIT());
                cauldronOwner.transferOwnership(safe);
            }
        }
        vm.stopBroadcast();
    }
}
