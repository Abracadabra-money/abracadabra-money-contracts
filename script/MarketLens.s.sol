// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "lenses/MarketLens.sol";
import "mixins/Create3Factory.sol";

contract MarketLensScript is BaseScript {
    // CREATE3 salts
    bytes32 constant MARKET_LENS_SALT = keccak256(bytes("MarketLens-v6-2023070702"));

    function deploy() public returns (MarketLens lens) {
        deployer.setAutoBroadcast(false);
        Create3Factory factory = Create3Factory(constants.getAddress(ChainId.All, "create3Factory"));
        string memory deploymentName = string.concat(constants.getChainName(block.chainid), "_MarketLens");

        vm.startBroadcast();
        lens = MarketLens(deployUsingCreate3(deploymentName, MARKET_LENS_SALT, type(MarketLens).creationCode, "", 0));
        vm.stopBroadcast();
    }
}
