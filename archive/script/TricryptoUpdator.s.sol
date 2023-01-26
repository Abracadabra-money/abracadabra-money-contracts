// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "periphery/TriCryptoUpdator.sol";

contract TriCryptoUpdatorScript is BaseScript {
    function run() public {
        vm.startBroadcast();

        // Deployment here.

        TriCryptoUpdator updater = new TriCryptoUpdator();

        if (!testing) {
            updater.transferOwnership(0xfddfE525054efaAD204600d00CA86ADb1Cc2ea8a, true, false);
        }
        
        vm.stopBroadcast();
    }
}
