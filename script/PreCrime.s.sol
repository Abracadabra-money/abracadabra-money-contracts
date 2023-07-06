// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import "mixins/Create3Factory.sol";
import "periphery/precrime/BaseOFTV2View.sol";

contract PreCrimeScript is BaseScript {
    using DeployerFunctions for Deployer;

    // CREATE3 salts
    bytes32 constant PROXY_OFTVIEW_SALT = keccak256(bytes("ProxyOftView-v1"));
    bytes32 constant INDIRECT_OFTVIEW_SALT = keccak256(bytes("IndirectOftView-v1"));
    bytes32 constant PRECRIME_SALT = keccak256(bytes("Precrime-v1"));

    function deploy() public returns (PreCrimeView precrime, BaseOFTV2View oftView) {
        deployer.setAutoBroadcast(false);
        Create3Factory factory = Create3Factory(constants.getAddress(ChainId.All, "create3Factory"));

        address oftv2 = constants.getAddress("oftv2", block.chainid);
        string memory chainName = constants.getChainName(block.chainid);
        string memory viewDeploymentName = string.concat(chainName, "_OFTV2View");
        string memory precrimeDeploymentName = string.concat(chainName, "_Precrime");

        // Always redeploy when testing, otherwise the address in the deployment file will be used
        // So if we made any changes to test, it won't load the new contract
        if (testing) {
            deployer.ignoreDeployment("Mainnet_ProxyOFTV2View");
            deployer.ignoreDeployment("Mainnet_Precrime");
        }

        if (!deployer.has(viewDeploymentName)) {
            if (block.chainid == ChainId.Mainnet) {
                oftView = ProxyOFTV2View(
                    factory.deploy(
                        PROXY_OFTVIEW_SALT,
                        abi.encodePacked(
                            type(ProxyOFTV2View).creationCode,
                            abi.encode(oftv2) // Mainnet LzOFTV2 Proxy
                        ),
                        0
                    )
                );
            } else {
                oftView = deployer.deploy_IndirectOFTV2View(viewDeploymentName, oftv2);

                oftView = IndirectOFTV2View(
                    factory.deploy(
                        INDIRECT_OFTVIEW_SALT,
                        abi.encodePacked(
                            type(IndirectOFTV2View).creationCode,
                            abi.encode(oftv2) // Altchain Indirect LzOFTV2
                        ),
                        0
                    )
                );
            }
        }

        if (!deployer.has(precrimeDeploymentName)) {
            precrime = PreCrimeView(
                factory.deploy(
                    INDIRECT_OFTVIEW_SALT,
                    abi.encodePacked(
                        type(PreCrimeView).creationCode,
                        abi.encode(uint16(constants.getLzChainId(block.chainid)), address(oftView), 100, tx.origin)
                    ),
                    0
                )
            );
        }
    }
}
