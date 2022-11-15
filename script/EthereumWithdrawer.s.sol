// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "utils/BaseScript.sol";

contract MyScript is BaseScript {
    function run() public {
        vm.startBroadcast();

        // Deployment here.
        //setAddress("mainnet.multiSig", 0x5f0DeE98360d8200b20812e174d139A1a633EDd2); // mim provider
        //setAddress("mainnet.spellTreasury", 0x5A7C5505f3CFB9a0D9A8493EC41bf27EE48c406D); // spell treasury

        vm.stopBroadcast();
    }
}
