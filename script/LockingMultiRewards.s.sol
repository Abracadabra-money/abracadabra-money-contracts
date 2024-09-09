// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {LockingMultiRewards} from "/staking/LockingMultiRewards.sol";

contract LockingMultiRewardsScript is BaseScript {
    function deploy() public returns (LockingMultiRewards staking) {
        address safe = toolkit.getAddress("safe.ops");

        vm.startBroadcast();
        staking = deployWithParameters(toolkit.getAddress("mim"), 30_000, 7 days, 13 weeks, tx.origin);

        // set default rewards
        if (block.chainid == ChainId.Arbitrum) {
            staking.addReward(toolkit.getAddress("arb"));
        }

        staking.setMinLockAmount(100 ether);
        staking.setOperator(toolkit.getAddress("rewardDistributors.epochBasedMultiRewards"), true); // allows distributor to call notifyRewardAmount

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
        staking = LockingMultiRewards(deploy("LockingMultiRewards", "LockingMultiRewards.sol:LockingMultiRewards", params));
    }
}
