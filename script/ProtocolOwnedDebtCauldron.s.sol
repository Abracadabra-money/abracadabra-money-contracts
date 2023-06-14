// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "cauldrons/ProtocolOwnedDebtCauldron.sol";

contract ProtocolOwnedDebtCauldronScript is BaseScript {
    function deploy() public returns (ProtocolOwnedDebtCauldron cauldron){
        vm.startBroadcast();
        cauldron = new ProtocolOwnedDebtCauldron();
        vm.stopBroadcast();
    }
}
