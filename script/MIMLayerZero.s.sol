// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import "interfaces/IMintableBurnable.sol";
import "mixins/Operatable.sol";

contract MIMLayerZeroScript is BaseScript {
    using DeployerFunctions for Deployer;

    function deploy() public returns (LzProxyOFTV2 proxyOFTV2, LzIndirectOFTV2 indirectOFTV2, IMintableBurnable minterBurner) {
        uint8 sharedDecimals = 8;
        address mim = constants.getAddress("mim", block.chainid);
        address lzEndpoint = constants.getAddress("LZendpoint", block.chainid);
        string memory chainName = constants.getChainName(block.chainid);

        if (block.chainid == ChainId.Mainnet) {
            proxyOFTV2 = deployer.deploy_LzProxyOFTV2("Mainnet_ProxyOFTV2", mim, sharedDecimals, lzEndpoint);
            vm.broadcast();
            proxyOFTV2.setUseCustomAdapterParams(true);
        } else {
            minterBurner = deployer.deploy_ElevatedMinterBurner(string.concat(chainName, "_ElevatedMinterBurner"), IMintableBurnable(mim));
            indirectOFTV2 = deployer.deploy_LzIndirectOFTV2(
                string.concat(chainName, "_IndirectOFTV2"),
                mim,
                minterBurner,
                sharedDecimals,
                lzEndpoint
            );

            vm.broadcast();
            indirectOFTV2.setUseCustomAdapterParams(true);
            /// @notice The layerzero token needs to be able to mint/burn anyswap tokens
            /// Only change the operator if the ownership is still the deployer
            if (
                !Operatable(address(minterBurner)).operators(address(indirectOFTV2)) &&
                BoringOwnable(address(minterBurner)).owner() == tx.origin
            ) {
                startBroadcast();
                Operatable(address(minterBurner)).setOperator(address(indirectOFTV2), true);
                stopBroadcast();
            }
        }
    }
}
