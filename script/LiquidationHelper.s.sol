// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "periphery/LiquidationHelper.sol";

contract LiquidationHelperScript is BaseScript {
    function run() public returns (LiquidationHelper helper) {
        startBroadcast();

        helper = new LiquidationHelper{salt: bytes32(bytes("LiquidationHelper.s.sol-20230418-v1"))}(
            ERC20(constants.getAddress(block.chainid, "mim"))
        );

        stopBroadcast();
    }
}
