// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import {CauldronDeployLib} from "utils/CauldronDeployLib.sol";
import {CauldronV4WithHooks} from "/cauldrons/CauldronV4WithHooks.sol";

contract CauldronV4WithHooksScript is BaseScript {
    bytes32 private constant SALT = bytes32(keccak256("CauldronV4WithHooks_1727803734"));

    function deploy() public {
        address box = toolkit.getAddress("degenBox");
        address cauldronOwner = toolkit.getAddress("cauldronOwner");
        address withdrawer = toolkit.getAddress("cauldronFeeWithdrawer");
        address mim = toolkit.getAddress("mim");

        vm.startBroadcast();

        CauldronV4WithHooks mc = CauldronV4WithHooks(
            deployUsingCreate3(
                "CauldronV4WithHooks",
                SALT,
                "CauldronV4WithHooks.sol:CauldronV4WithHooks",
                abi.encode(box, mim, tx.origin)
            )
        );

        if (!testing()) {
            if (mc.owner() == tx.origin) {
                if (mc.feeTo() != withdrawer) {
                    mc.setFeeTo(withdrawer);
                }
                mc.transferOwnership(cauldronOwner);
            }
        }

        vm.stopBroadcast();
    }
}
