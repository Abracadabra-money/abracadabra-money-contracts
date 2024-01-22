// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {LockingMultiRewards} from "staking/LockingMultiRewards.sol";

contract LockingMultiRewardsScript is BaseScript {
    function deploy() public returns (LockingMultiRewards staking) {
        vm.startBroadcast();

        if (block.chainid != ChainId.Arbitrum) {
            revert("unsupported chain");
        }

        address safe = toolkit.getAddress(block.chainid, "safe.ops");

        bytes memory params;
        if (testing()) {
            params = abi.encode(toolkit.getAddress(block.chainid, "mim"), 30_000, 60 seconds, 10 days, tx.origin);
        } else {
            params = abi.encode(toolkit.getAddress(block.chainid, "mim"), 30_000, 7 weeks, 13 weeks, tx.origin);
        }

        staking = LockingMultiRewards(deploy("LockingMultiRewards", "LockingMultiRewards.sol:LockingMultiRewards", params));

        if (!testing()) {
            staking.transferOwnership(safe);
        }

        vm.stopBroadcast();
    }
}
