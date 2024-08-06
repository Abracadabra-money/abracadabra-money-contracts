// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {LibClone} from "@solady/utils/LibClone.sol";
import "forge-std/console2.sol";

contract MagicKodiakScript is BaseScript {
    function deploy() public {
        vm.startBroadcast();

        address mimBeraLP = 0x12C195768f65F282EA5F1B5C42755FBc910B0D8F;
        address magicKodiak = deploy(
            "MagicKodiakVault_BeraHoneyImpl",
            "MagicKodiakVault.sol:MagicKodiakVault",
            abi.encode(address(0), address(0))
        );

        address instance = LibClone.deployERC1967(magicKodiak, abi.encode(mimBeraLP, tx.origin));
        console2.log(instance);

        vm.stopBroadcast();
    }
}
