// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "utils/BaseScript.sol";
import "oracles/ProxyOracle.sol";
import "oracles/InverseOracle.sol";

contract LiquityScript is BaseScript {
    function run() public returns (ProxyOracle oracle) {
        address xMerlin = constants.getAddress("xMerlin");

        vm.startBroadcast();

        // ProxyOracle: 0x3Cc89EA432c36c8F96731765997722192202459D
        /*oracle = new ProxyOracle();
        InverseOracle oracleImpl = new InverseOracle(
            IAggregator(constants.getAddress("mainnet.chainlink.lusd")),
            IAggregator(address(0)),
            "Inverse LUSD"
        );

        oracle.changeOracleImplementation(oracleImpl);

        if (!testing) {
            oracle.transferOwnership(xMerlin, true, false);
        }*/

        oracle = ProxyOracle(0x3Cc89EA432c36c8F96731765997722192202459D);

        if (!testing) {}

        vm.stopBroadcast();
    }
}
