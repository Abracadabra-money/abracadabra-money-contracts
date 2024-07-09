// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {EpochBasedRewardDistributor} from "staking/distributors/EpochBasedRewardDistributor.sol";
import {MultiRewardDistributor} from "staking/distributors/MultiRewardDistributor.sol";

contract RewardDistributorsScript is BaseScript {
    bytes32 constant EPOCH_BASED_SALT = keccak256(bytes("EpochBasedRewardDistributor-1718122997"));
    bytes32 constant MULTI_REWARDS_SALT = keccak256(bytes("MultiRewardDistributor-1718122997"));

    function deploy() public returns (EpochBasedRewardDistributor epochDistributor, MultiRewardDistributor multiDistributor) {
        vm.startBroadcast();
        address gelatoProxy = toolkit.getAddress(block.chainid, "safe.devOps.gelatoProxy");
        address safe = toolkit.getAddress(block.chainid, "safe.ops");
        address vault = toolkit.getAddress(ChainId.All, "safe.rewards");

        epochDistributor = EpochBasedRewardDistributor(
            deployUsingCreate3(
                "EpochBasedRewardDistributor",
                EPOCH_BASED_SALT,
                "EpochBasedRewardDistributor.sol:EpochBasedRewardDistributor",
                abi.encode(vault, tx.origin)
            )
        );

        multiDistributor = MultiRewardDistributor(
            deployUsingCreate3(
                "MultiRewardDistributor",
                MULTI_REWARDS_SALT,
                "MultiRewardDistributor.sol:MultiRewardDistributor",
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
