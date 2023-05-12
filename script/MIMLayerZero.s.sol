// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import "interfaces/IMintableBurnable.sol";

contract MIMLayerZeroScript is BaseScript {
    using DeployerFunctions for Deployer;

    function deploy() public {
        uint8 sharedDecimals = 8;
        address mim = constants.getAddress("mim", block.chainid);
        address lzEndpoint = constants.getAddress("LZendpoint", block.chainid);

        if (block.chainid == ChainId.Mainnet) {
            deployer.deploy_ProxyOFTV2("Mainnet_ProxyOFTV2", mim, sharedDecimals, lzEndpoint);
        } else if (block.chainid == ChainId.BSC) {
            deployer.deploy_ElevatedMinterBurner("BSC_ElevatedMinterBurner", IMintableBurnable(mim));
            deployer.deploy_IndirectOFTV2("BSC_IndirectOFTV2", mim, IMintableBurnable(mim), sharedDecimals, lzEndpoint);
        } else if (block.chainid == ChainId.Polygon) {
            deployer.deploy_ElevatedMinterBurner("Polygon_ElevatedMinterBurner", IMintableBurnable(mim));
            deployer.deploy_IndirectOFTV2("Polygon_IndirectOFTV2", mim, IMintableBurnable(mim), sharedDecimals, lzEndpoint);
        } else if (block.chainid == ChainId.Fantom) {
            deployer.deploy_ElevatedMinterBurner("Fantom_ElevatedMinterBurner", IMintableBurnable(mim));
            deployer.deploy_IndirectOFTV2("Fantom_IndirectOFTV2", mim, IMintableBurnable(mim), sharedDecimals, lzEndpoint);
        } else if (block.chainid == ChainId.Optimism) {
            deployer.deploy_ElevatedMinterBurner("Optimism_ElevatedMinterBurner", IMintableBurnable(mim));
            deployer.deploy_IndirectOFTV2("Optimism_IndirectOFTV2", mim, IMintableBurnable(mim), sharedDecimals, lzEndpoint);
        } else if (block.chainid == ChainId.Arbitrum) {
            deployer.deploy_ElevatedMinterBurner("Arbitrum_ElevatedMinterBurner", IMintableBurnable(mim));
            deployer.deploy_IndirectOFTV2("Arbitrum_IndirectOFTV2", mim, IMintableBurnable(mim), sharedDecimals, lzEndpoint);
        } else if (block.chainid == ChainId.Avalanche) {
            deployer.deploy_ElevatedMinterBurner("Avalanche_ElevatedMinterBurner", IMintableBurnable(mim));
            deployer.deploy_IndirectOFTV2("Avalanche_IndirectOFTV2", mim, IMintableBurnable(mim), sharedDecimals, lzEndpoint);
        } else if (block.chainid == ChainId.Moonriver) {
            deployer.deploy_ElevatedMinterBurner("Moonriver_ElevatedMinterBurner2", IMintableBurnable(mim));
            deployer.deploy_IndirectOFTV2("Moonriver_IndirectOFTV2", mim, IMintableBurnable(mim), sharedDecimals, lzEndpoint);
        } else {
            revert(string.concat("MIMLayerZeroScript: unsupported chain ", vm.toString(block.chainid)));
        }
    }
}
