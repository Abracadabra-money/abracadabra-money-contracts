// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "src/lenses/GmxLens.sol";

contract GmxLensScript is BaseScript {
    function run() public returns (GmxLens lens) {
        startBroadcast();

        lens = new GmxLens{salt: bytes32(bytes("GmxLensScript.s.sol-20230214-v2"))}(
            IGmxGlpManager(0x3963FfC9dff443c2A94f21b129D429891E32ec18),
            IGmxVault(0x489ee077994B6658eAfA855C308275EAd8097C4A),
            IGmxVaultReader(0xfebB9f4CAC4cD523598fE1C5771181440143F24A),
            IGmxPositionManager(payable(0xb87a436B93fFE9D75c5cFA7bAcFff96430b09868)),
            IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1)
        );

        stopBroadcast();
    }
}
