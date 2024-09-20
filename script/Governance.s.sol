// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {TimelockControllerUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/TimelockControllerUpgradeable.sol";
import {SpellTimelock} from "/governance/SpellTimelock.sol";
import {SpellGovernor} from "/governance/SpellGovernor.sol";
import {MSpellStakingHub, MSpellStakingSpoke} from "/governance/MSpellStakingWithVoting.sol";
import {LayerZeroChainId} from "utils/Toolkit.sol";
import {LayerZeroLib} from "utils/LayerZeroLib.sol";
import {MSpellStakingRewardHandler} from "/periphery/MSpellStakingRewardHandler.sol";

uint256 constant LZ_RECEIVE_GAS_LIMIT = 200_000;

contract GovernanceScript is BaseScript {
    bytes32 constant STAKING_SALT = keccak256(bytes("MSpellStaking-1725419025"));
    bytes32 constant GOVERNOR_SALT = keccak256(bytes("SpellGovernor-1725419025"));
    bytes32 constant TIMELOCK_SALT = keccak256(bytes("SpellTimelock-1725419025"));
    bytes32 constant REWARD_HANDLER_SALT = keccak256(bytes("MSpellStakingRewardHandler-1725419025"));

    // Proxies
    SpellTimelock timelock;
    SpellGovernor governor;

    // Implementations
    address timelockImpl;
    address governorImpl;
    address stakingHubImpl;
    address stakingSpokeImpl;

    // Voting staking
    address stakingHub;
    address stakingSpoke;

    address rewardHandler;
    address mim;
    address mimOftV2;
    address lzEndpoint;

    address spell;

    function deploy() public returns (SpellTimelock, address timelockOwner, MSpellStakingHub, MSpellStakingSpoke) {
        mim = toolkit.getAddress(block.chainid, "mim");
        lzEndpoint = toolkit.getAddress(block.chainid, "LZendpoint");
        mimOftV2 = toolkit.getAddress(block.chainid, "mim.oftv2");

        if (block.chainid == ChainId.Mainnet) {
            spell = toolkit.getAddress(ChainId.Mainnet, "spell");
        } else {
            spell = toolkit.getAddress("spellV2");
        }

        if (spell == address(0)) {
            revert("spell address not found");
        }

        vm.startBroadcast();

        rewardHandler = deployUsingCreate3(
            "MSpellStakingRewardHandler",
            REWARD_HANDLER_SALT,
            "MSpellStakingRewardHandler.sol:MSpellStakingRewardHandler",
            abi.encode(mim, mimOftV2, tx.origin)
        );

        _deploy();
        vm.stopBroadcast();

        return (timelock, tx.origin, MSpellStakingHub(stakingHub), MSpellStakingSpoke(stakingSpoke));
    }

    function _deploy() internal {
        if (block.chainid == ChainId.Arbitrum) {
            stakingHub = deployUpradeableUsingCreate3(
                "MSpellStakingHub",
                STAKING_SALT,
                "MSpellStakingWithVoting.sol:MSpellStakingHub",
                abi.encode(mim, spell, lzEndpoint),
                abi.encodeCall(MSpellStakingHub.initialize, tx.origin)
            );

            bytes memory trustedRemote = LayerZeroLib.getRecipient(stakingHub, stakingHub);
            MSpellStakingHub(stakingHub).setTrustedRemote(LayerZeroChainId.Mainnet, trustedRemote);
            MSpellStakingHub(stakingHub).setTrustedRemote(LayerZeroChainId.Avalanche, trustedRemote);
            MSpellStakingHub(stakingHub).setTrustedRemote(LayerZeroChainId.Fantom, trustedRemote);

            governor = SpellGovernor(
                payable(
                    deployUpradeableUsingCreate3(
                        "SpellGovernor",
                        GOVERNOR_SALT,
                        "SpellGovernor.sol:SpellGovernor",
                        "",
                        abi.encodeCall(
                            SpellGovernor.initialize,
                            (MSpellStakingHub(stakingHub), TimelockControllerUpgradeable(payable(timelock)), tx.origin)
                        )
                    )
                )
            );

            address[] memory proposers = new address[](1);
            address[] memory executors = new address[](1);

            proposers[0] = address(governor);
            executors[0] = address(0); // anyone is allowed to execute on the timelock

            timelock = SpellTimelock(
                payable(
                    deployUpradeableUsingCreate3(
                        "SpellTimelock",
                        TIMELOCK_SALT,
                        "SpellTimelock.sol:SpellTimelock",
                        "",
                        abi.encodeCall(SpellTimelock.initialize, (2 days, proposers, executors, tx.origin))
                    )
                )
            );

            MSpellStakingRewardHandler(rewardHandler).setOperator(address(stakingHub), true);

            if (!testing()) {
                MSpellStakingHub(stakingHub).setRewardHandler(rewardHandler);

                /// @note should be done manually once it's all tested and ready to go
                //address safe = toolkit.getAddress(block.chainid, "safe.ops");
                //SpellTimelock _tl = SpellTimelock(payable(timelock));
                //_tl.revokeRole(_tl.DEFAULT_ADMIN_ROLE(), tx.origin);
                //governor.transferOwnership(timelock);
                //MSpellStakingHub(stakingHub).transferOwnership(address(timelock));
            }
        } else {
            stakingSpoke = deployUpradeableUsingCreate3(
                "MSpellStakingSpoke",
                STAKING_SALT,
                "MSpellStakingWithVoting.sol:MSpellStakingSpoke",
                abi.encode(mim, spell, lzEndpoint, LayerZeroChainId.Arbitrum),
                abi.encodeCall(MSpellStakingSpoke.initialize, tx.origin)
            );

            bytes memory trustedRemote = LayerZeroLib.getRecipient(stakingSpoke, stakingSpoke);
            MSpellStakingSpoke(stakingSpoke).setMinDstGas(LayerZeroChainId.Arbitrum, 0, LZ_RECEIVE_GAS_LIMIT);
            MSpellStakingSpoke(stakingSpoke).setTrustedRemote(LayerZeroChainId.Arbitrum, trustedRemote);

            MSpellStakingRewardHandler(rewardHandler).setOperator(address(stakingHub), true);

            if (!testing()) {
                MSpellStakingSpoke(stakingSpoke).setRewardHandler(rewardHandler);
                //MSpellStakingSpoke(stakingHub).transferOwnership(address(owner));
            }
        }
    }
}
