// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {MultiRewards} from "/staking/MultiRewards.sol";

contract MultiRewardsScript is BaseScript {
    function deploy() public returns (MultiRewards staking) {
        vm.startBroadcast();

        address safe = toolkit.getAddress(block.chainid, "safe.ops");

        staking = MultiRewards(
            deploy(
                "MultiRewards",
                "MultiRewards.sol:MultiRewards",
                abi.encode(toolkit.getAddress(block.chainid, "mimswap.pools.mimdeusd"), tx.origin)
            )
        );

        //staking.addReward(toolkit.getAddress("arb"), 604800);
        //staking.addReward(toolkit.getAddress("spell"), 604800);
        staking.addReward(toolkit.getAddress("bSpell"), 604800);

        if (!testing()) {
            staking.transferOwnership(safe);
        }

        vm.stopBroadcast();
    }
}
