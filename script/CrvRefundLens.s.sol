// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "lenses/CrvRefundLens.sol";

contract CrvRefundLensScript is BaseScript {
    function deploy() public returns (CrvRefundLens lens) {
        startBroadcast();

        lens = new CrvRefundLens{salt: bytes32(bytes("CrvRefundLens.s.sol-20230526-v1"))}();

        stopBroadcast();
    }
}
