// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import "periphery/TestContract.sol";

contract TestContractScript is BaseScript {
    using DeployerFunctions for Deployer;

    // CREATE3 salts
    bytes32 constant SALT = keccak256(bytes("abcdefgh-3"));

    function deploy() public {
        vm.startBroadcast();

        address c = deployUsingCreate3(
            string.concat(constants.getChainName(block.chainid), "_TestContract"),
            SALT,
            "TestContract.sol:TestContract",
            abi.encode(constants.getAddress("safe.ops", block.chainid)),
            0
        );


        vm.stopBroadcast();
    }
}
