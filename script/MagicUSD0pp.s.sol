// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {LibClone} from "@solady/utils/LibClone.sol";
import {MagicUSD0pp} from "/tokens/MagicUSD0pp.sol";

contract MagicUSD0ppScript is BaseScript {
    bytes32 constant VAULT_SALT = keccak256("MagicUSD0pp_1727739582");

    function deploy() public returns (MagicUSD0pp instance) {
        vm.startBroadcast();

        instance = MagicUSD0pp(
            deployUpgradeableUsingCreate3(
                "MagicUSD0pp",
                VAULT_SALT,
                "MagicUSD0pp.sol:MagicUSD0pp",
                abi.encode(toolkit.getAddress("usd0++")),
                abi.encodeCall(MagicUSD0pp.initialize, (tx.origin))
            )
        );

        if (instance.owner() != tx.origin) {
            revert("owner should be the deployer");
        }

        if (!instance.operators(tx.origin)) {
            instance.setOperator(tx.origin, true);
        }

        if(!testing()) {
            instance.transferOwnership(toolkit.getAddress("safe.ops"));
        }

        vm.stopBroadcast();
    }
}
