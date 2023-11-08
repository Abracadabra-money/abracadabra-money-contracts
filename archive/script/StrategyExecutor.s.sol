// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";

contract StrategyExecutorScript is BaseScript {
    using DeployerFunctions for Deployer;

    bytes32 constant SALT = keccak256(bytes("StrategyExecutor-1695127052"));

    function deploy() public {
        vm.startBroadcast();

        // On KAVA verify using this:
        // forge verify-contract --chain-id 2222 --num-of-optimizations 800 --watch --constructor-args $(cast abi-encode "constructor(address)" "0xfB3485c2e209A5cfBDC1447674256578f1A80eE3") --compiler-version v0.8.20+commit.a1b79de6 0x8d493Be67643361a4d0882bf65216adf7430447c src/periphery/StrategyExecutor.sol:StrategyExecutor --verifier blockscout --verifier-url https://kavascan.com/api\?
        deployUsingCreate3(
            toolkit.prefixWithChainName(block.chainid, "StrategyExecutor"),
            SALT,
            "StrategyExecutor.sol:StrategyExecutor",
            abi.encode(tx.origin),
            0
        );

        vm.stopBroadcast();
    }
}
