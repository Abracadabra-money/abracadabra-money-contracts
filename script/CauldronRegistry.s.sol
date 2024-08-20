// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {BaseScript} from "utils/BaseScript.sol";
import {CauldronInfo as ToolkitCauldronInfo, CauldronStatus} from "utils/Toolkit.sol";
import {CauldronRegistry, CauldronInfo as RegistryCauldronInfo} from "/periphery/CauldronRegistry.sol";
import {IOwnableOperators} from "/interfaces/IOwnableOperators.sol";

contract CauldronRegistryScript is BaseScript {
    bytes32 constant SALT = keccak256(bytes("CauldronRegistry-1716556947"));

    CauldronRegistry registry;

    function deploy() public {
        address safe = toolkit.getAddress("safe.ops");

        vm.startBroadcast();
        registry = CauldronRegistry(
            deployUsingCreate3("CauldronRegistry", SALT, "CauldronRegistry.sol:CauldronRegistry", abi.encode(tx.origin))
        );
        vm.stopBroadcast();

        vm.startBroadcast();
        RegistryCauldronInfo[] memory cauldrons = _getCauldronsToRegister();
        registry.add(cauldrons);

        if (!testing()) {
            if (IOwnableOperators(address(registry)).owner() == tx.origin && !IOwnableOperators(address(registry)).operators(tx.origin)) {
                IOwnableOperators(address(registry)).setOperator(tx.origin, true);
            }

            IOwnableOperators(address(registry)).transferOwnership(safe);
        }
        vm.stopBroadcast();
    }

    function _getCauldronsToRegister() internal view returns (RegistryCauldronInfo[] memory cauldrons) {
        ToolkitCauldronInfo[] memory items = toolkit.getCauldrons(block.chainid);
        uint count;

        for (uint256 i = 0; i < items.length; ++i) {
            if (items[i].status == CauldronStatus.Removed) {
                continue;
            }

            if (!registry.registered(items[i].cauldron)) {
                count++;
            }
        }

        cauldrons = new RegistryCauldronInfo[](count);
        for (uint256 i = 0; i < items.length; ++i) {
            if (items[i].status == CauldronStatus.Removed) {
                continue;
            }

            if (!registry.registered(items[i].cauldron)) {
                cauldrons[i] = RegistryCauldronInfo(items[i].cauldron, items[i].version, items[i].status == CauldronStatus.Deprecated);
            }
        }
    }
}
