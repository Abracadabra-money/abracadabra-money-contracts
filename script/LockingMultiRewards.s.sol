// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {LockingMultiRewards} from "staking/LockingMultiRewards.sol";

contract LockingMultiRewardsScript is BaseScript {
    function deploy() public returns (LockingMultiRewards staking) {
        vm.startBroadcast();
        staking = deployWithParameters(toolkit.getAddress(block.chainid, "mim"), 30_000, 7 weeks, 13 weeks, tx.origin);
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

        address safe = toolkit.getAddress(block.chainid, "safe.ops");

        bytes memory params = abi.encode(stakingToken, boost, rewardDuration, lockDuration, origin);
        staking = LockingMultiRewards(deploy("LockingMultiRewards", "LockingMultiRewards.sol:LockingMultiRewards", params));

        if (!testing()) {
            staking.transferOwnership(safe);
        }
    }
}
