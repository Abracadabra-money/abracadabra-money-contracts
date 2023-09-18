// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";

contract LzMulticallSenderReceiverScript is BaseScript {
    bytes32 constant SALT = keccak256(bytes("LzMulticallSenderReceiver-1695069265"));

    using DeployerFunctions for Deployer;

    function deploy() public {
        deployUsingCreate3(
            toolkit.prefixWithChainName(block.chainid, "LzMulticallSenderReceiver"),
            SALT,
            "LzMulticallSenderReceiver.sol:LzMulticallSenderReceiver",
            abi.encode(toolkit.getAddress(block.chainid, "LZendpoint"), tx.origin),
            0
        );
    }
}
