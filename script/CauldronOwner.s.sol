// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {BaseScript, ChainId} from "utils/BaseScript.sol";
import {CauldronOwner} from "/periphery/CauldronOwner.sol";
import {CauldronRegistry} from "/periphery/CauldronRegistry.sol";

contract CauldronOwnerScript is BaseScript {
    bytes32 constant SALT = keccak256(bytes("CauldronOwner-1716556947"));

    function deploy() public returns (CauldronOwner cauldronOwner) {
        address safe = toolkit.getAddress(block.chainid, "safe.ops");
        address mim = toolkit.getAddress(block.chainid, "mim");
        CauldronRegistry registry = CauldronRegistry(toolkit.getAddress(ChainId.All, "cauldronRegistry"));

        address hexagate = toolkit.getAddress(ChainId.All, "hexagate.threatMonitor");

        vm.startBroadcast();
        cauldronOwner = CauldronOwner(
            deployUsingCreate3("CauldronOwner", SALT, "CauldronOwner.sol:CauldronOwner", abi.encode(safe, mim, tx.origin))
        );

        if (cauldronOwner.registry() != registry) {
            cauldronOwner.setRegistry(registry);
        }

        if (!testing()) {
            if (cauldronOwner.owner() == tx.origin) {
                if (!cauldronOwner.hasAnyRole(0xfB3485c2e209A5cfBDC1447674256578f1A80eE3, cauldronOwner.ROLE_DISABLE_BORROWING())) {
                    cauldronOwner.grantRoles(0xfB3485c2e209A5cfBDC1447674256578f1A80eE3, cauldronOwner.ROLE_DISABLE_BORROWING());
                }
                if (!cauldronOwner.hasAnyRole(0xfddfE525054efaAD204600d00CA86ADb1Cc2ea8a, cauldronOwner.ROLE_DISABLE_BORROWING())) {
                    cauldronOwner.grantRoles(0xfddfE525054efaAD204600d00CA86ADb1Cc2ea8a, cauldronOwner.ROLE_DISABLE_BORROWING());
                }
                if (!cauldronOwner.hasAnyRole(0x941ec857134B13c255d6EBEeD1623b1904378De9, cauldronOwner.ROLE_DISABLE_BORROWING())) {
                    cauldronOwner.grantRoles(0x941ec857134B13c255d6EBEeD1623b1904378De9, cauldronOwner.ROLE_DISABLE_BORROWING());
                }
                if (!cauldronOwner.hasAnyRole(0x3c1Cb7D4c0ce0dc72eDc7Ea06acC866e62a8f1d8, cauldronOwner.ROLE_DISABLE_BORROWING())) {
                    cauldronOwner.grantRoles(0x3c1Cb7D4c0ce0dc72eDc7Ea06acC866e62a8f1d8, cauldronOwner.ROLE_DISABLE_BORROWING());
                }
                if (!cauldronOwner.hasAnyRole(0x1081246e16c36fb6A9c1F4E6e28B27CeE28c01CA, cauldronOwner.ROLE_DISABLE_BORROWING())) {
                    cauldronOwner.grantRoles(0x1081246e16c36fb6A9c1F4E6e28B27CeE28c01CA, cauldronOwner.ROLE_DISABLE_BORROWING());
                }
                if (!cauldronOwner.hasAnyRole(0x8764F421AB0C682b4Ba1d7e269C09187c1EfbFAF, cauldronOwner.ROLE_DISABLE_BORROWING())) {
                    cauldronOwner.grantRoles(0x8764F421AB0C682b4Ba1d7e269C09187c1EfbFAF, cauldronOwner.ROLE_DISABLE_BORROWING());
                }
                if (!cauldronOwner.hasAnyRole(hexagate, cauldronOwner.ROLE_DISABLE_BORROWING())) {
                    cauldronOwner.grantRoles(hexagate, cauldronOwner.ROLE_DISABLE_BORROWING());
                }

                cauldronOwner.transferOwnership(safe);
            }
        }
        vm.stopBroadcast();
    }
}
