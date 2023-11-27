// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {MultiRewardsStaking} from "periphery/MultiRewardsStaking.sol";

contract MultiRewardsStakingScript is BaseScript {
    function deploy() public returns (MultiRewardsStaking staking) {
        vm.startBroadcast();

        if (block.chainid != ChainId.Arbitrum) {
            revert("unsupported chain");
        }

        address safe = toolkit.getAddress(block.chainid, "safe.ops");

        staking = MultiRewardsStaking(
            deploy(
                "MultiRewardsStaking",
                "MultiRewardsStaking.sol:MultiRewardsStaking",
                abi.encode(toolkit.getAddress(block.chainid, "curve.mim2crv"), tx.origin)
            )
        );

        if (!testing()) {
            staking.transferOwnership(safe);
        }

        vm.stopBroadcast();
    }
}
