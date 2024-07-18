// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {EpochBasedRewardDistributor} from "/staking/distributors/EpochBasedRewardDistributor.sol";
import {MultiRewardDistributor} from "/staking/distributors/MultiRewardDistributor.sol";

contract RewardDistributorsScript is BaseScript {
    bytes32 constant EPOCH_BASED_SALT = keccak256(bytes("EpochBasedRewardDistributor-000000002"));
    bytes32 constant MULTI_REWARDS_SALT = keccak256(bytes("MultiRewardDistributor-000000002"));
    EpochBasedRewardDistributor epochDistributor;
    MultiRewardDistributor multiDistributor;

    function deploy() public returns (EpochBasedRewardDistributor, MultiRewardDistributor) {
        address gelatoProxy;
        try toolkit.getAddress(block.chainid, "safe.devOps.gelatoProxy") returns (address a) {
            gelatoProxy = a;
        } catch {}

        address safe = toolkit.getAddress(block.chainid, "safe.ops");
        address vault = toolkit.getAddress("safe.ops");

        vm.startBroadcast();
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

        if (!testing()) {
            _configureRewards();

            if (block.chainid != ChainId.Kava) {
                _setOperator(gelatoProxy);
            }

            _setOperator(0x000000E6cee66A117a0B436670C1E897A5D7Fcf9);
            _setOperator(0xfB3485c2e209A5cfBDC1447674256578f1A80eE3);
            _setOperator(0xfddfE525054efaAD204600d00CA86ADb1Cc2ea8a);

            epochDistributor.transferOwnership(safe);
            multiDistributor.transferOwnership(safe);
        }

        vm.stopBroadcast();

        return (epochDistributor, multiDistributor);
    }

    function _configureRewards() internal {
        if (block.chainid == ChainId.Kava) {
            if (multiDistributor.rewardDistributions(0xcF4f8E9A113433046B990980ebce5c3fA883067f, toolkit.getAddress("wKava")) == 0) {
                multiDistributor.setRewardDistribution(
                    0xcF4f8E9A113433046B990980ebce5c3fA883067f,
                    toolkit.getAddress("wKava"),
                    20_000 ether
                );
            }
        }

        if (block.chainid == ChainId.Arbitrum) {
            multiDistributor.setRewardDistribution(
                0xc30911b52b5752447aB08615973e434c801CD652,
                toolkit.getAddress("spell"),
                20_000_000 ether
            ); // mim/usdt LP

            multiDistributor.setRewardDistribution(
                0x280c64c4C4869CF2A6762EaDD4701360C1B11F97,
                toolkit.getAddress("spell"),
                20_000_000 ether
            ); // mim/usdc LP
        }
    }

    function _setOperator(address operator) internal {
        if (!epochDistributor.operators(operator)) {
            epochDistributor.setOperator(operator, true);
        }
        if (!multiDistributor.operators(operator)) {
            multiDistributor.setOperator(operator, true);
        }
    }
}
