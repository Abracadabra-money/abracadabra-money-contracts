// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {MagicJUSDC} from "tokens/MagicJUSDC.sol";
import {MagicJUSDCRewardHandler} from "periphery/MagicJUSDCRewardHandler.sol";
import {IMagicJUSDCRewardHandler} from "interfaces/IMagicJUSDCRewardHandler.sol";

contract JUSDCCauldronScript is BaseScript {
    function deploy() public {
        //address router = toolkit.getAddress(block.chainid, "jones.router");
        //address jusdc = toolkit.getAddress(block.chainid, "jones.jusdc");

        vm.startBroadcast();
        //deploy("MagicJUSDC", "MagicJUSDC.sol:MagicJUSDC", abi.encode(jusdc, "magicJUSDC", "mJUSDC"));
        
        vm.stopBroadcast();
    }
}
