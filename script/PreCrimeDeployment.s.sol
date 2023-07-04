// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";

contract PreCrimeDeploymentScript is BaseScript {
    using DeployerFunctions for Deployer;

    function deploy() public returns (ProxyOFTV2PreCrimeView precrime, ProxyOFTV2View proxyView, OFTV2View oftView) {
        // deployer.deploy_TestContract("TestContract", "foobar", tx.origin);
        address oftv2 = constants.getAddress("oftv2", block.chainid);
        address lzEndpoint = constants.getAddress("LZendpoint", block.chainid);
        string memory chainName = constants.getChainName(block.chainid);

        if (block.chainid == ChainId.Mainnet) {
            proxyView = deployer.deploy_ProxyOFTV2View("Mainnet_ProxyOFTV2View", oftv2);
            precrime = deployer.deploy_ProxyOFTV2PreCrimeView("Mainnet_Precrime", uint16(constants.getLzChainId(block.chainid)), address(proxyView), type(uint64).max);
        } else {
            oftView = deployer.deploy_OFTV2View(string.concat(chainName, "_OFTV2View"), oftv2);
            precrime = deployer.deploy_ProxyOFTV2PreCrimeView(string.concat(chainName, "_Precrime"), uint16(constants.getLzChainId(block.chainid)), address(proxyView), type(uint64).max);
        }
    }
}
