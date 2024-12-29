// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {LibClone} from "@solady/utils/LibClone.sol";
import {MagicUSD0pp} from "/tokens/MagicUSD0pp.sol";
import {MagicUSD0ppHarvester} from "/harvesters/MagicUSD0ppHarvester.sol";
import {OwnableRoles} from "@solady/auth/OwnableRoles.sol";
import {OwnableOperators} from "/mixins/OwnableOperators.sol";

contract MagicUSD0ppScript is BaseScript {
    bytes32 constant VAULT_SALT = keccak256("MagicUSD0pp_1727739582");

    function deploy() public returns (MagicUSD0pp vault, MagicUSD0pp implementationV2, MagicUSD0ppHarvester harvester) {
        vm.startBroadcast();

        vault = MagicUSD0pp(
            deployUpgradeableUsingCreate3(
                "MagicUSD0pp",
                VAULT_SALT,
                "MagicUSD0pp.sol:MagicUSD0pp",
                abi.encode(toolkit.getAddress("usd0++")),
                abi.encodeCall(MagicUSD0pp.initialize, (tx.origin))
            )
        );

        implementationV2 = MagicUSD0pp(
            deploy("Mainnet_MagicUSD0ppImpl_V2", "MagicUSD0pp.sol:MagicUSD0pp", abi.encode(toolkit.getAddress("usd0++")))
        );

        if (!vault.operators(tx.origin)) {
            vault.setOperator(tx.origin, true);
        }

        address usualToken = 0xC4441c2BE5d8fA8126822B9929CA0b81Ea0DE38E;
        address odosRouterV2 = 0xCf5540fFFCdC3d510B18bFcA6d2b9987b0772559;

        harvester = MagicUSD0ppHarvester(
            deploy("MagicUSD0ppHarvester", "MagicUSD0ppHarvester.sol:MagicUSD0ppHarvester", abi.encode(vault, tx.origin, usualToken))
        );

        harvester.setAllowedRouter(odosRouterV2, true);
        harvester.setFeeParameters(toolkit.getAddress("safe.yields"), 500); // 5%

        address gelato = toolkit.getAddress("safe.devOps.gelatoProxy");
        OwnableRoles(address(harvester)).grantRoles(0xfB3485c2e209A5cfBDC1447674256578f1A80eE3, harvester.ROLE_OPERATOR());
        OwnableRoles(address(harvester)).grantRoles(0x8764F421AB0C682b4Ba1d7e269C09187c1EfbFAF, harvester.ROLE_OPERATOR());
        OwnableRoles(address(harvester)).grantRoles(address(gelato), harvester.ROLE_OPERATOR());

        if (!testing()) {
            address owner = OwnableOperators(address(vault)).owner();
            if (owner != toolkit.getAddress("safe.ops")) {
                vault.transferOwnership(toolkit.getAddress("safe.ops"));
            }

            owner = OwnableRoles(address(harvester)).owner();
            if (owner != toolkit.getAddress("safe.ops")) {
                harvester.transferOwnership(toolkit.getAddress("safe.ops"));
            }
        }

        vm.stopBroadcast();
    }
}
