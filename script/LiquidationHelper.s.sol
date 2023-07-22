// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "mixins/Create3Factory.sol";
import "periphery/LiquidationHelper.sol";

contract LiquidationHelperScript is BaseScript {
    // CREATE3 salts
    bytes32 constant LIQUIDATION_HELPER_SALT = keccak256(bytes("LiquidationHelperV1"));

    function deploy() public returns (LiquidationHelper helper) {
        vm.startBroadcast();

        helper = LiquidationHelper(
            deployUsingCreate3(
                string.concat(toolkit.getChainName(block.chainid), "_LiquidationHelper"),
                LIQUIDATION_HELPER_SALT,
                "LiquidationHelper.sol:LiquidationHelper",
                abi.encode(toolkit.getAddress("mim", block.chainid)),
                0
            )
        );

        vm.stopBroadcast();
    }
}
