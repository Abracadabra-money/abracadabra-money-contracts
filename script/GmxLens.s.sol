// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "src/lenses/GmxLens.sol";

contract GmxLensScript is BaseScript {
    function run() public returns (GmxLens lens) {
        startBroadcast();

        lens = new GmxLens(
            IGmxGlpManager(0x3963FfC9dff443c2A94f21b129D429891E32ec18),
            IGmxVault(0x489ee077994B6658eAfA855C308275EAd8097C4A)
        );

        stopBroadcast();
    }
}
