// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";

contract PotionPointRedeemerScript is BaseScript {
    function deploy() public {
        vm.startBroadcast();
        deploy("PotionPointRedeemer", "PotionPointRedeemer.sol:PotionPointRedeemer", abi.encode(tx.origin));
        vm.stopBroadcast();
    }
}