// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {OwnableOperators} from "/mixins/OwnableOperators.sol";
import {BoundSpellActionSender, CrosschainActions} from "src/periphery/BoundSpellCrosschainActions.sol";
import {OwnableRoles} from "@solady/auth/OwnableRoles.sol";
import {SpellPowerStaking} from "/staking/SpellPowerStaking.sol";
import {IOwnableOperators} from "/interfaces/IOwnableOperators.sol";

contract BoundSpellCrosschainActionsScript is BaseScript {
    bytes32 constant SALT = keccak256(bytes("BoundSpellCrosschainActions-1728488645"));

    function deploy() public returns (address receiverOrSender) {
        vm.startBroadcast();

        address safe = toolkit.getAddress("safe.ops");
        address spellOft = toolkit.getAddress("spellV2");
        address bSpellOft = toolkit.getAddress("bSpell");
        address spellPowerStaking;
        address boundSpellLocker;

        if (block.chainid == ChainId.Arbitrum) {
            spellPowerStaking = toolkit.getAddress("bSpell.staking");
            boundSpellLocker = toolkit.getAddress("bSpell.locker");

            receiverOrSender = deployUsingCreate3(
                "BoundSpellActionReceiver",
                SALT,
                "BoundSpellCrosschainActions.sol:BoundSpellActionReceiver",
                abi.encode(spellOft, bSpellOft, spellPowerStaking, boundSpellLocker, tx.origin)
            );
        } else {
            receiverOrSender = deployUsingCreate3(
                "BoundSpellActionSender",
                SALT,
                "BoundSpellCrosschainActions.sol:BoundSpellActionSender",
                abi.encode(spellOft, bSpellOft, tx.origin)
            );

            BoundSpellActionSender(receiverOrSender).setGasPerAction(CrosschainActions.MINT_AND_STAKE_BOUNDSPELL, 300000);
            BoundSpellActionSender(receiverOrSender).setGasPerAction(CrosschainActions.STAKE_BOUNDSPELL, 200000);
        }

        if (!testing()) {
            address hexagate = toolkit.getAddress("hexagate.threatMonitor");
            OwnableOperators(receiverOrSender).setOperator(hexagate, true);
            OwnableOperators(receiverOrSender).setOperator(0xfB3485c2e209A5cfBDC1447674256578f1A80eE3, true);
            OwnableOperators(receiverOrSender).setOperator(0xfddfE525054efaAD204600d00CA86ADb1Cc2ea8a, true);
            OwnableOperators(receiverOrSender).setOperator(0x8764F421AB0C682b4Ba1d7e269C09187c1EfbFAF, true);

            if (block.chainid == ChainId.Arbitrum) {
                if (OwnableRoles(spellPowerStaking).owner() == tx.origin) {
                    OwnableRoles(address(spellPowerStaking)).grantRoles(
                        address(receiverOrSender),
                        SpellPowerStaking(spellPowerStaking).ROLE_OPERATOR()
                    );
                    OwnableOperators(address(boundSpellLocker)).setOperator(address(receiverOrSender), true);
                    IOwnableOperators(address(spellPowerStaking)).transferOwnership(safe);
                } else {
                    // Schedule the above when owner is not tx.origin
                }
            }

            OwnableOperators(receiverOrSender).transferOwnership(safe);
        }

        vm.stopBroadcast();
    }
}
