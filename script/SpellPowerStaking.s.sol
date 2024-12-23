// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {SpellPowerStaking} from "/staking/SpellPowerStaking.sol";
import {IOwnableOperators} from "/interfaces/IOwnableOperators.sol";
import {TokenLocker} from "/periphery/TokenLocker.sol";
import {MultiRewardsClaimingHandler} from "/periphery/MultiRewardsClaimingHandler.sol";

bytes32 constant SPELL_POWER_STAKING_SALT = keccak256(bytes("SpellPowerStaking-1734984832"));

contract SpellPowerStakingScript is BaseScript {
    function deploy() public returns (SpellPowerStaking staking, MultiRewardsClaimingHandler rewardHandler) {
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

        rewardHandler = MultiRewardsClaimingHandler(
            deploy("MultiRewardsClaimingHandler", "MultiRewardsClaimingHandler.sol:MultiRewardsClaimingHandler", abi.encode(tx.origin))
        );

        if (!rewardHandler.operators(address(staking))) {
            rewardHandler.setOperator(address(staking), true);
        }

        if (address(staking.rewardHandler()) != address(rewardHandler)) {
            staking.setRewardHandler(address(rewardHandler));
        }

        if (!staking.isSupportedReward(mim)) {
            staking.addReward(mim, 7 days);
        }
        if (!staking.isSupportedReward(bSpell)) {
            staking.addReward(bSpell, 7 days);
        }

        uint256 role = staking.ROLE_REWARD_DISTRIBUTOR();

        if (staking.hasAnyRole(rewardDistributor, role)) {
            staking.grantRoles(rewardDistributor, role);
        }

        if (staking.lockupPeriod() != 1 days) {
            staking.setLockupPeriod(1 days);
        }

        if (!testing()) {
            IOwnableOperators(address(staking)).transferOwnership(safe);
        }

        vm.stopBroadcast();
    }
}

contract SpellPowerStakingUpgradeScript is BaseScript {
    function deploy() public {
        vm.startBroadcast();
        address bSpell = toolkit.getAddress("bSpell");
        deploy("SpellPowerStakingImpl", "SpellPowerStaking.sol:SpellPowerStaking", abi.encode(bSpell, address(0)));
        vm.stopBroadcast();

        /// @note Once deployed, schedule the upgrade on the SpellPowerStaking proxy
    }
}
