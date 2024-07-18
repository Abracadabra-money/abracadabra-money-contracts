// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {LockingMultiRewards} from "/staking/LockingMultiRewards.sol";

contract LockingMultiRewardsScript is BaseScript {
    function deploy() public returns (LockingMultiRewards staking) {
        address safe = toolkit.getAddress(block.chainid, "safe.ops");

        vm.startBroadcast();
        staking = deployWithParameters(toolkit.getAddress(block.chainid, "mim"), 30_000, 7 days, 13 weeks, tx.origin);

        staking.addReward(toolkit.getAddress(block.chainid, "arb"));
        staking.setMinLockAmount(100 ether);
        staking.setOperator(toolkit.getAddress(block.chainid, "rewardDistributors.epochBased"), true); // allows distributor to call notifyRewardAmount
        
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
        if (block.chainid != ChainId.Arbitrum) {
            revert("unsupported chain");
        }

        bytes memory params = abi.encode(stakingToken, boost, rewardDuration, lockDuration, origin);
        staking = LockingMultiRewards(deploy("LockingMultiRewards", "LockingMultiRewards.sol:LockingMultiRewards", params));
    }
}
