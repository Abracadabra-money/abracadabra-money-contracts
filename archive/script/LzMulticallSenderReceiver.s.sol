// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import "utils/LayerZeroLib.sol";
import "interfaces/ILzApp.sol";

contract LzMulticallSenderReceiverScript is BaseScript {
    bytes32 constant SALT = keccak256(bytes("LzMulticallSenderReceiver-1695069265"));

    using LayerZeroLib for ILzApp;
    using DeployerFunctions for Deployer;

    function deploy() public {
        vm.startBroadcast();

        // On KAVA verify using this:
        // forge verify-contract --chain-id 2222 --num-of-optimizations 800 --watch --constructor-args $(cast abi-encode "constructor(address,address)" "0xb6319cC6c8c27A8F5dAF0dD3DF91EA35C4720dd7" "0xfB3485c2e209A5cfBDC1447674256578f1A80eE3") --compiler-version v0.8.20+commit.a1b79de6 0x84C9Bb8B81037C642f2Eb6486a9bdfF526CdEbe0 src/periphery/LzMulticallSenderReceiver.sol:LzMulticallSenderReceiver --verifier blockscout --verifier-url https://kavascan.com/api\?
        ILzApp app = ILzApp(
            deployUsingCreate3(
                toolkit.prefixWithChainName(block.chainid, "LzMulticallSenderReceiver"),
                SALT,
                "LzMulticallSenderReceiver.sol:LzMulticallSenderReceiver",
                abi.encode(toolkit.getAddress(block.chainid, "LZendpoint"), tx.origin),
                0
            )
        );

        if (block.chainid == ChainId.Kava) {
            //app.setTrustedRemote(LayerZeroChainId.Arbitrum, abi.encodePacked(address(app), address(app)));
            app.setInboundConfirmations(LayerZeroChainId.Arbitrum, uint16(1));
        }
        if (block.chainid == ChainId.Arbitrum) {
            app.setTrustedRemote(LayerZeroChainId.Kava, abi.encodePacked(address(app), address(app)));
            app.setOutboundConfirmations(LayerZeroChainId.Kava, uint16(1));
        }

        vm.stopBroadcast();
    }
}
