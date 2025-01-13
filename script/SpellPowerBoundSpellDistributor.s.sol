// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {SpellPowerBoundSpellDistributor} from "/staking/distributors/SpellPowerBoundSpellDistributor.sol";

contract SpellPowerBoundSpellDistributorScript is BaseScript {
    function deploy() public returns (SpellPowerBoundSpellDistributor distributor) {
        address bSpell = toolkit.getAddress("bSpell");
        address staking = toolkit.getAddress("bSpell.staking");
        address gelato = toolkit.getAddress("safe.devOps.gelatoProxy");
        address safe = toolkit.getAddress("safe.ops");

        vm.startBroadcast();
        distributor = SpellPowerBoundSpellDistributor(
            deploy(
                "SpellPowerBoundSpellDistributor",
                "SpellPowerBoundSpellDistributor.sol:SpellPowerBoundSpellDistributor",
                abi.encode(staking, bSpell, tx.origin)
            )
        );

        distributor.setOperator(gelato, true);

        if (!testing()) {
            distributor.transferOwnership(safe);
        }

        vm.stopBroadcast();
    }
}
