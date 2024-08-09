// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {IERC20} from "@BoringSolidity/interfaces/IERC20.sol";
import {BaseScript, ChainId} from "utils/BaseScript.sol";
import {CauldronReducer} from "/periphery/CauldronReducer.sol";
import {CauldronOwner} from "/periphery/CauldronOwner.sol";

contract CauldronReducerScript is BaseScript {
    function deploy() public returns (CauldronReducer cauldronReducer) {
        address owner = testing() ? tx.origin : toolkit.getAddress("safe.ops");
        CauldronOwner cauldronOwner = CauldronOwner(toolkit.getAddress("cauldronOwner"));
        address mim = toolkit.getAddress("mim");

        vm.startBroadcast();

        cauldronReducer = CauldronReducer(
            deploy("CauldronReducer", "CauldronReducer.sol:CauldronReducer", abi.encode(owner, cauldronOwner, mim, type(uint256).max))
        );

        vm.stopBroadcast();
    }
}
