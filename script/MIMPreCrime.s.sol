// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {Create3Factory} from "mixins/Create3Factory.sol";
import {BaseOFTV2View} from "periphery/precrime/BaseOFTV2View.sol";
import {ProxyOFTV2View} from "periphery/precrime/ProxyOFTV2View.sol";
import {IndirectOFTV2View} from "periphery/precrime/IndirectOFTV2View.sol";
import {PreCrimeView} from "periphery/precrime/PreCrimeView.sol";
import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";

contract MIMPreCrimeScript is BaseScript {
    // CREATE3 salts
    bytes32 constant PROXYOFT_VIEW_SALT = keccak256(bytes("ProxyOftView-1689125386"));
    bytes32 constant INDIRECTOFT_VIEW_SALT = keccak256(bytes("IndirectOftView-1689125387"));
    bytes32 constant PRECRIME_SALT = keccak256(bytes("Precrime-1689125387"));

    function deploy() public returns (PreCrimeView precrime, BaseOFTV2View oftView) {
        address oftv2 = toolkit.getAddress("oftv2", block.chainid);

        vm.startBroadcast();
        if (block.chainid == ChainId.Mainnet) {
            oftView = ProxyOFTV2View(
                deployUsingCreate3(
                    "OFTV2View",
                    PROXYOFT_VIEW_SALT,
                    "ProxyOFTV2View.sol:ProxyOFTV2View",
                    abi.encode(oftv2), // Mainnet LzOFTV2 Proxy
                    0
                )
            );
        } else {
            /*
                forge verify-contract --num-of-optimizations 400 --watch \
                    --constructor-args $(cast abi-encode "constructor(address)" "0xcA8A205a579e06Cb1bE137EA3A5E5698C091f018") \
                    --compiler-version v0.8.20+commit.a1b79de6 0x6B3763adB57cD4EecD32eA49369D47d3fD1d594c src/periphery/precrime/IndirectOFTV2View.sol:IndirectOFTV2View \
                    --verifier-url https://api.blastscan.io/api \
                    -e ${BLAST_ETHERSCAN_KEY}
            */
            oftView = IndirectOFTV2View(
                deployUsingCreate3(
                    "OFTV2View",
                    INDIRECTOFT_VIEW_SALT,
                    "IndirectOFTV2View.sol:IndirectOFTV2View",
                    abi.encode(oftv2), // Altchain Indirect LzOFTV2
                    0
                )
            );
        }

        /*
            forge verify-contract --num-of-optimizations 400 --watch \
                --constructor-args $(cast abi-encode "constructor(address,uint16,address,uint64)" "0xfB3485c2e209A5cfBDC1447674256578f1A80eE3" 243 0x6B3763adB57cD4EecD32eA49369D47d3fD1d594c 100) \
                --compiler-version v0.8.20+commit.a1b79de6 0x374748A045B37c7541E915199EdBf392915909a4 src/periphery/precrime/PreCrimeView.sol:PreCrimeView \
                --verifier-url https://api.blastscan.io/api \
                -e ${BLAST_ETHERSCAN_KEY}
        */
        precrime = PreCrimeView(
            deployUsingCreate3(
                "Precrime",
                PRECRIME_SALT,
                "PreCrimeView.sol:PreCrimeView",
                abi.encode(tx.origin, uint16(toolkit.getLzChainId(block.chainid)), address(oftView), uint64(100)),
                0
            )
        );
        vm.stopBroadcast();
    }
}
