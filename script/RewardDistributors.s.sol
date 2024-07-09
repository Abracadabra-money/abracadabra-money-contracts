// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {EpochBasedRewardDistributor, MultiRewardsDistributor} from "periphery/RewardDistributors.sol";

contract RewardDistributorsScript is BaseScript {
    bytes32 constant EPOCH_BASED_SALT = keccak256(bytes("EpochBasedRewardDistributor-1718122997"));
    bytes32 constant MULTI_REWARDS_SALT = keccak256(bytes("MultiRewardsDistributor-1718122997"));

    function deploy() public returns (EpochBasedRewardDistributor epochDistributor, MultiRewardsDistributor multiDistributor) {
        vm.startBroadcast();
        address gelatoProxy = toolkit.getAddress(block.chainid, "safe.devOps.gelatoProxy");
        address safe = toolkit.getAddress(block.chainid, "safe.ops");
        address vault = toolkit.getAddress(ChainId.All, "safe.rewards");

        epochDistributor = EpochBasedRewardDistributor(
            deployUsingCreate3(
                "EpochBasedRewardDistributor",
                EPOCH_BASED_SALT,
                "RewardDistributors.sol:EpochBasedRewardDistributor",
                abi.encode(vault, tx.origin)
            )
        );

        multiDistributor = MultiRewardsDistributor(
            deployUsingCreate3(
                "MultiRewardsDistributor",
                MULTI_REWARDS_SALT,
                "RewardDistributors.sol:MultiRewardsDistributor",
                abi.encode(vault, tx.origin)
            )
        );

        epochDistributor.setOperator(gelatoProxy, true);
        multiDistributor.setOperator(gelatoProxy, true);

        if (!testing()) {
            epochDistributor.transferOwnership(safe);
            multiDistributor.transferOwnership(safe);
        }

        vm.stopBroadcast();
    }
}
