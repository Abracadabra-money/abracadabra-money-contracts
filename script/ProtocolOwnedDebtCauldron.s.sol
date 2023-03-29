// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "cauldrons/ProtocolOwnedDebtCauldron.sol";

contract ProtocolOwnedDebtCauldronScript is BaseScript {
    function run() public returns (ProtocolOwnedDebtCauldron cauldron){
        startBroadcast();

        cauldron = new ProtocolOwnedDebtCauldron();

        // Deployment here.
        
        stopBroadcast();
    }
}
