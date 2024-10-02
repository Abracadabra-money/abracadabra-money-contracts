// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "utils/CauldronDeployLib.sol";
import "/cauldrons/CheckpointCauldronV4.sol";

contract CheckpointCauldronV4Script is BaseScript {
    bytes32 private constant SALT = bytes32(keccak256("CheckpointCauldronV4_1727803734"));

    function deploy() public {
        address box = toolkit.getAddress("degenBox");
        address cauldronOwner = toolkit.getAddress("cauldronOwner");
        address withdrawer = toolkit.getAddress("cauldronFeeWithdrawer");
        address mim = toolkit.getAddress("mim");

        vm.startBroadcast();

        CheckpointCauldronV4 mc = CheckpointCauldronV4(
            deployUsingCreate3(
                "CheckpointCauldronV4",
                SALT,
                "CheckpointCauldronV4.sol:CheckpointCauldronV4",
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
