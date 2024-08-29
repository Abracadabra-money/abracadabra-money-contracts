// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {MultiRewards} from "/staking/MultiRewards.sol";

contract MultiRewardsScript is BaseScript {
    function deploy() public returns (MultiRewards staking) {
        vm.startBroadcast();

        if (block.chainid != ChainId.Arbitrum) {
            revert("unsupported chain");
        }

        address safe = toolkit.getAddress(block.chainid, "safe.ops");

        staking = MultiRewards(
            deploy(
                "MultiRewards",
                "MultiRewards.sol:MultiRewards",
                abi.encode(toolkit.getAddress(block.chainid, "mimswap.pools.mimusdc"), tx.origin)
            )
        );

        //staking.addReward(toolkit.getAddress(block.chainid, "arb"), 604800);
        //staking.addReward(toolkit.getAddress(block.chainid, "spell"), 604800);
        //staking.addReward(toolkit.getAddress(block.chainid, "bSpell"), 604800);

        if (!testing()) {
            staking.transferOwnership(safe);
        }

        vm.stopBroadcast();
    }
}
