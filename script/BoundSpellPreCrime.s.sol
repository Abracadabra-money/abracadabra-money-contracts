// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC20} from "@BoringSolidity/interfaces/IERC20.sol";
import "utils/BaseScript.sol";
import {Create3Factory} from "/mixins/Create3Factory.sol";
import {BaseOFTV2View} from "@abracadabra-oftv2/precrime/BaseOFTV2View.sol";
import {ProxyOFTV2View} from "@abracadabra-oftv2/precrime/ProxyOFTV2View.sol";
import {IndirectOFTV2View} from "@abracadabra-oftv2/precrime/IndirectOFTV2View.sol";
import {PreCrimeView} from "@abracadabra-oftv2/precrime/PreCrimeView.sol";

contract BoundSpellPreCrimeScript is BaseScript {
    // CREATE3 salts
    bytes32 constant PROXYOFT_VIEW_SALT = keccak256(bytes("BoundSpellProxyOftView-1689125391"));
    bytes32 constant INDIRECTOFT_VIEW_SALT = keccak256(bytes("BoundSpellIndirectOftView-1689125391"));
    bytes32 constant PRECRIME_SALT = keccak256(bytes("BoundSpellPrecrime-1689125391"));

    function deploy() public returns (PreCrimeView precrime, BaseOFTV2View oftView) {
        address oftv2 = toolkit.getAddress("bspell.oftv2");

        vm.startBroadcast();
        if (block.chainid == ChainId.Arbitrum) {
            oftView = ProxyOFTV2View(
                deployUsingCreate3(
                    "BSPELL_OFTV2View",
                    PROXYOFT_VIEW_SALT,
                    "ProxyOFTV2View.sol:ProxyOFTV2View",
                    abi.encode(oftv2), // Arbitrum LzOFTV2 Proxy
                    0
                )
            );
        } else {
            oftView = IndirectOFTV2View(
                deployUsingCreate3(
                    "BSPELL_OFTV2View",
                    INDIRECTOFT_VIEW_SALT,
                    "IndirectOFTV2View.sol:IndirectOFTV2View",
                    abi.encode(oftv2), // Altchain Indirect LzOFTV2
                    0
                )
            );
        }

        precrime = PreCrimeView(
            deployUsingCreate3(
                "BSPELL_Precrime",
                PRECRIME_SALT,
                "PreCrimeView.sol:PreCrimeView",
                abi.encode(tx.origin, uint16(toolkit.getLzChainId(block.chainid)), address(oftView), uint64(100)),
                0
            )
        );
        vm.stopBroadcast();
    }
}
