// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {SpellPowerStaking} from "/staking/SpellPowerStaking.sol";
import {IOwnableOperators} from "/interfaces/IOwnableOperators.sol";
import {TokenLocker} from "/periphery/TokenLocker.sol";

bytes32 constant SPELL_POWER_STAKING_SALT = keccak256(bytes("SpellPowerStaking-1727108303"));

contract SpellPowerStakingScript is BaseScript {
    function deploy() public returns (SpellPowerStaking staking) {
        address mim = toolkit.getAddress("mim");
        address bSpell = toolkit.getAddress("bSpell");
        address rewardDistributor = toolkit.getAddress("rewardDistributors.multiRewards");
        address safe = toolkit.getAddress("safe.ops");

        vm.startBroadcast();

        staking = SpellPowerStaking(
            deployUpgradeableUsingCreate3(
                "SpellPowerStaking",
                SPELL_POWER_STAKING_SALT,
                "SpellPowerStaking.sol:SpellPowerStaking",
                abi.encode(bSpell, address(0)), // constructor
                abi.encodeCall(SpellPowerStaking.initialize, (tx.origin)) // intializer
            )
        );

        if (!staking.isSupportedReward(mim)) {
            staking.addReward(mim, 7 days);
        }
        if (!staking.isSupportedReward(bSpell)) {
            staking.addReward(bSpell, 7 days);
        }
        staking.grantRoles(rewardDistributor, staking.ROLE_REWARD_DISTRIBUTOR());
        staking.setLockupPeriod(1 days);

        if (!testing()) {
            IOwnableOperators(address(staking)).transferOwnership(safe);
        }

        vm.stopBroadcast();
    }
}
