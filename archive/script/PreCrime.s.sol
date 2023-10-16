// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import "mixins/Create3Factory.sol";
import "periphery/precrime/BaseOFTV2View.sol";
import "forge-std/console2.sol";

contract PreCrimeScript is BaseScript {
    using DeployerFunctions for Deployer;

    // CREATE3 salts
    bytes32 constant PROXYOFT_VIEW_SALT = keccak256(bytes("ProxyOftView-1689125386"));
    bytes32 constant INDIRECTOFT_VIEW_SALT = keccak256(bytes("IndirectOftView-1689125387"));
    bytes32 constant PRECRIME_SALT = keccak256(bytes("Precrime-1689125387"));

    function deploy() public returns (PreCrimeView precrime, BaseOFTV2View oftView) {
        deployer.setAutoBroadcast(false);

        address oftv2 = toolkit.getAddress("oftv2", block.chainid);
        string memory chainName = toolkit.getChainName(block.chainid);

        vm.startBroadcast();
        if (block.chainid == ChainId.Mainnet) {
            oftView = ProxyOFTV2View(
                deployUsingCreate3(
                    string.concat(chainName, "_OFTV2View"),
                    PROXYOFT_VIEW_SALT,
                    "ProxyOFTV2View.sol:ProxyOFTV2View",
                    abi.encode(oftv2), // Mainnet LzOFTV2 Proxy
                    0
                )
            );
        } else {
            oftView = IndirectOFTV2View(
                deployUsingCreate3(
                    string.concat(chainName, "_OFTV2View"),
                    INDIRECTOFT_VIEW_SALT,
                    "IndirectOFTV2View.sol:IndirectOFTV2View",
                    abi.encode(oftv2), // Altchain Indirect LzOFTV2
                    0
                )
            );
        }

        precrime = PreCrimeView(
            deployUsingCreate3(
                string.concat(chainName, "_Precrime"),
                PRECRIME_SALT,
                "PreCrimeView.sol:PreCrimeView",
                abi.encode(tx.origin, uint16(toolkit.getLzChainId(block.chainid)), address(oftView), uint64(100)),
                0
            )
        );
        vm.stopBroadcast();
    }
}
