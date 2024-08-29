// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {BaseScript} from "utils/BaseScript.sol";
import {ChainId} from "utils/Toolkit.sol";
import {CauldronReducer} from "/periphery/CauldronReducer.sol";

contract CauldronReducerScript is BaseScript {
    bytes32 private constant SALT = bytes32(keccak256("CauldronReducer-1723246012"));

    function deploy() public returns (CauldronReducer cauldronReducer) {
        address cauldronOwner = toolkit.getAddress("cauldronOwner");
        address safe = toolkit.getAddress("safe.ops");
        address mim = toolkit.getAddress("mim");

        vm.startBroadcast();

        cauldronReducer = CauldronReducer(
            deployUsingCreate3("CauldronReducer", SALT, "CauldronReducer.sol:CauldronReducer", abi.encode(cauldronOwner, mim, tx.origin))
        );

        // gelato
        if (block.chainid != ChainId.Kava) {
            address gelato = toolkit.getAddress("safe.devOps.gelatoProxy");

            if (!cauldronReducer.operators(gelato)) {
                cauldronReducer.setOperator(gelato, true);
            }
        }

        // dreamy
        if (!cauldronReducer.operators(0x000000E6cee66A117a0B436670C1E897A5D7Fcf9)) {
            cauldronReducer.setOperator(0x000000E6cee66A117a0B436670C1E897A5D7Fcf9, true);
        }
        if (!cauldronReducer.operators(0x8764F421AB0C682b4Ba1d7e269C09187c1EfbFAF)) {
            cauldronReducer.setOperator(0x8764F421AB0C682b4Ba1d7e269C09187c1EfbFAF, true);
        }

        // deployor
        if (!cauldronReducer.operators(tx.origin)) {
            cauldronReducer.setOperator(tx.origin, false);
        }

        if (!testing()) {
            cauldronReducer.transferOwnership(safe);
        }

        vm.stopBroadcast();
    }
}
