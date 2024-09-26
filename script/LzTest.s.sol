// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";

contract LzTestScript is BaseScript {
    //salt
    bytes32 constant salt = bytes32("LzTest5");

    function deploy() public {
        vm.startBroadcast();

        address oft = toolkit.getAddress("spell.oftv2");

        // SENDER
        if (block.chainid != ChainId.Arbitrum) {
            address spellV2 = toolkit.getAddress("spellV2");
            address sender = deployUsingCreate3("LzSender1", salt, "LzTest.sol:LzSender", abi.encode(oft, tx.origin));
            SafeTransferLib.safeApprove(spellV2, sender, 1000 ether);
        }
        // RECEIVER
        else {
            deployUsingCreate3("LzReceiver1", salt, "LzTest.sol:LzReceiver", abi.encode(oft));
        }

        vm.stopBroadcast();
    }
}
