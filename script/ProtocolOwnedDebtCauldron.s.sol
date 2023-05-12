// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/LegacyBaseScript.sol";
import "cauldrons/ProtocolOwnedDebtCauldron.sol";

contract ProtocolOwnedDebtCauldronScript is LegacyBaseScript {
    function run() public returns (ProtocolOwnedDebtCauldron cauldron){
        startBroadcast();
        cauldron = new ProtocolOwnedDebtCauldron();
        stopBroadcast();
    }
}
