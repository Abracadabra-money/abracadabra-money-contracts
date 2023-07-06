// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";

contract PreCrimeScript is BaseScript {
    using DeployerFunctions for Deployer;

    function deploy() public returns (PreCrimeView precrime, ProxyOFTV2View proxyView, IndirectOFTV2View indirectOftView) {
        address oftv2 = constants.getAddress("oftv2", block.chainid);
        string memory chainName = constants.getChainName(block.chainid);
/*
        if (block.chainid == ChainId.Mainnet) {
            proxyView = deployer.deploy_ProxyOFTV2View("Mainnet_ProxyOFTV2View", oftv2);
            precrime = deployer.deploy_ProxyOFTV2PreCrimeView("Mainnet_Precrime", uint16(constants.getLzChainId(block.chainid)), address(proxyView), 100);
        } else {
            oftView = deployer.deploy_OFTV2View(string.concat(chainName, "_OFTV2View"), oftv2);
            precrime = deployer.deploy_ProxyOFTV2PreCrimeView(string.concat(chainName, "_Precrime"), uint16(constants.getLzChainId(block.chainid)), address(oftView), 100);
        }
        */
    }
}
