// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {MultiRewardsStaking} from "periphery/MultiRewardsStaking.sol";

contract MultiRewardsStakingScript is BaseScript {
    function deploy() public returns (MultiRewardsStaking staking) {
        vm.startBroadcast();

        if (block.chainid != ChainId.Arbitrum) {
            revert("unsoported chain");
        }

        staking = MultiRewardsStaking(
            deploy(
                "MultiRewardsStaking",
                "MultiRewardsStaking.sol:MultiRewardsStaking",
                abi.encode(toolkit.getAddress(block.chainid, "curve.mim2crv"), tx.origin)
            )
        );

        staking.addReward(toolkit.getAddress(block.chainid, "arb"), 7 days);
        staking.addReward(toolkit.getAddress(block.chainid, "spell"), 7 days);
        
        vm.stopBroadcast();
    }
}
