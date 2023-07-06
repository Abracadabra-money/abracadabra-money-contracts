// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import "mixins/Create3Factory.sol";
import "periphery/precrime/BaseOFTV2View.sol";
import "forge-std/console2.sol";

contract PreCrimeScript is BaseScript {
    using DeployerFunctions for Deployer;

    // CREATE3 salts
    bytes32 constant PROXYOFT_VIEW_SALT = keccak256(bytes("ProxyOftView-v1"));
    bytes32 constant INDIRECTOFT_VIEW_SALT = keccak256(bytes("IndirectOftView-v1"));
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
            deployer.ignoreDeployment(viewDeploymentName);
            deployer.ignoreDeployment(precrimeDeploymentName);
        }

        if (deployer.has(viewDeploymentName)) {
            oftView = BaseOFTV2View(deployer.getAddress(viewDeploymentName));
        } else {
            if (block.chainid == ChainId.Mainnet) {
                oftView = ProxyOFTV2View(
                    factory.deploy(
                        PROXYOFT_VIEW_SALT,
                        abi.encodePacked(
                            type(ProxyOFTV2View).creationCode,
                            abi.encode(oftv2) // Mainnet LzOFTV2 Proxy
                        ),
                        0
                    )
                );
            } else {
                oftView = IndirectOFTV2View(
                    factory.deploy(
                        INDIRECTOFT_VIEW_SALT,
                        abi.encodePacked(
                            type(IndirectOFTV2View).creationCode,
                            abi.encode(oftv2) // Altchain Indirect LzOFTV2
                        ),
                        0
                    )
                );
            }
        }

        if (deployer.has(precrimeDeploymentName)) {
            precrime = PreCrimeView(deployer.getAddress(precrimeDeploymentName));
        } else {
            precrime = PreCrimeView(
                factory.deploy(
                    PRECRIME_SALT,
                    abi.encodePacked(
                        type(PreCrimeView).creationCode,
                        abi.encode(tx.origin, uint16(constants.getLzChainId(block.chainid)), address(oftView), uint64(100))
                    ),
                    0
                )
            );
        }
    }
}
