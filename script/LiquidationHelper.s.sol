// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "mixins/Create3Factory.sol";
import "periphery/LiquidationHelper.sol";

contract LiquidationHelperScript is BaseScript {
    function deploy() public returns (LiquidationHelper helper) {
        startBroadcast();
        ERC20 MIM = ERC20(constants.getAddress(block.chainid, "mim"));

        if (testing) {
            helper = new LiquidationHelper(MIM);
        } else {
            Create3Factory factory = Create3Factory(constants.getAddress("create3Factory"));

            helper = LiquidationHelper(
                factory.deploy(
                    keccak256(bytes("LiquidationHelper.s.sol-20230418-v1")),
                    abi.encodePacked(type(LiquidationHelper).creationCode, abi.encode(MIM)),
                    0
                )
            );
        }

        stopBroadcast();
    }
}
