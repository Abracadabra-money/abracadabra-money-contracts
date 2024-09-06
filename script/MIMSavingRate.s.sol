// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {LockingMultiRewards} from "/staking/LockingMultiRewards.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";

contract MIMSavingRateScript is BaseScript {
    using SafeTransferLib for address;

    bytes32 constant SALT = keccak256(bytes("MIMSavingRate-000000001"));

    function deploy() public returns (LockingMultiRewards staking) {
        address safe = toolkit.getAddress("safe.ops");
        address gelatoProxy = toolkit.getAddress("safe.devOps.gelatoProxy");
        address mim = toolkit.getAddress("mim");
        address arb = toolkit.getAddress("arb");
        address spell = toolkit.getAddress("spell");
        address bSpell = toolkit.getAddress("bSpell");

        vm.startBroadcast();
        staking = deployWithParameters(mim, 30_000, 7 days, 13 weeks, tx.origin);

        // set default rewards
        if (block.chainid == ChainId.Arbitrum) {
            staking.addReward(arb);
            staking.addReward(spell);
            staking.addReward(bSpell);
            staking.addReward(mim);
        }

        staking.setMinLockAmount(100 ether);
        staking.setOperator(toolkit.getAddress("rewardDistributors.epochBasedMultiRewards"), true); // allows distributor to call notifyRewardAmount
        staking.setOperator(gelatoProxy, true); // allows gelato to call processExpiredLocks
        staking.setOperator(0xfB3485c2e209A5cfBDC1447674256578f1A80eE3, true); // for testing

        // Distribute test rewards when deploying
        bool initialDistribution = false;

        if (initialDistribution) {
            mim.safeApprove(address(staking), type(uint256).max);
            arb.safeApprove(address(staking), type(uint256).max);
            spell.safeApprove(address(staking), type(uint256).max);
            bSpell.safeApprove(address(staking), type(uint256).max);
            staking.stake(1 ether);
            staking.notifyRewardAmount(arb, 2 ether, 0);
            staking.notifyRewardAmount(spell, 10_000 ether, 0);
            staking.notifyRewardAmount(mim, 1 ether, 0);
        }

        if (!testing()) {
            staking.transferOwnership(safe);
        }

        vm.stopBroadcast();
    }

    function deployWithParameters(
        address stakingToken,
        uint256 boost,
        uint256 rewardDuration,
        uint256 lockDuration,
        address origin
    ) public returns (LockingMultiRewards staking) {
        bytes memory params = abi.encode(stakingToken, boost, rewardDuration, lockDuration, origin);
        staking = LockingMultiRewards(
            deployUsingCreate3("MimSavingRateStaking", SALT, "LockingMultiRewards.sol:LockingMultiRewards", params)
        );
    }
}
