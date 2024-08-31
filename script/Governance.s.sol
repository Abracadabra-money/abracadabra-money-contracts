// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {LibClone} from "@solady/utils/LibClone.sol";
import {TimelockControllerUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/TimelockControllerUpgradeable.sol";
import {SpellTimelock} from "/governance/SpellTimelock.sol";
import {SpellGovernor} from "/governance/SpellGovernor.sol";
import {MSpellStakingHub, MSpellStakingSpoke} from "/governance/MSpellStakingWithVoting.sol";
import {LayerZeroChainId} from "utils/Toolkit.sol";
import {LayerZeroLib} from "utils/LayerZeroLib.sol";

uint256 constant LZ_RECEIVE_GAS_LIMIT = 150_000;

contract GovernanceScript is BaseScript {
    bytes32 constant STAKING_SALT = keccak256(bytes("MSpellStaking-1"));
    bytes32 constant GOVERNOR_SALT = keccak256(bytes("SpellGovernor-1"));
    bytes32 constant TIMELOCK_SALT = keccak256(bytes("SpellTimelock-1"));

    // Proxies
    SpellTimelock timelock;
    SpellGovernor governor;

    // Implementations
    address timelockImpl;
    address governorImpl;

    // Voting staking
    address stakingHub;
    address stakingSpoke;

    function deploy() public returns (SpellTimelock, address timelockOwner, MSpellStakingHub, MSpellStakingSpoke) {
        address mim = toolkit.getAddress(block.chainid, "mim");
        address spell = toolkit.getAddress(block.chainid, "spell");
        address lzEndpoint = toolkit.getAddress(block.chainid, "LZendpoint");

        vm.startBroadcast();

        if (block.chainid == ChainId.Arbitrum) {
            stakingHub = deployUsingCreate3(
                "MSpellStakingHub",
                STAKING_SALT,
                "MSpellStakingWithVoting.sol:MSpellStakingHub",
                abi.encode(mim, spell, lzEndpoint, tx.origin)
            );

            bytes memory trustedRemote = LayerZeroLib.getRecipient(stakingHub, stakingHub);
            MSpellStakingHub(stakingHub).setTrustedRemote(LayerZeroChainId.Mainnet, trustedRemote);
            MSpellStakingHub(stakingHub).setTrustedRemote(LayerZeroChainId.Avalanche, trustedRemote);
            MSpellStakingHub(stakingHub).setTrustedRemote(LayerZeroChainId.Fantom, trustedRemote);

            _deployImplementations();
            _deployProxies();
        } else {
            stakingSpoke = deployUsingCreate3(
                "MSpellStakingSpoke",
                STAKING_SALT,
                "MSpellStakingWithVoting.sol:MSpellStakingSpoke",
                abi.encode(mim, spell, lzEndpoint, LayerZeroChainId.Arbitrum, tx.origin)
            );

            bytes memory trustedRemote = LayerZeroLib.getRecipient(stakingSpoke, stakingSpoke);
            MSpellStakingSpoke(stakingSpoke).setMinDstGas(LayerZeroChainId.Arbitrum, 0, LZ_RECEIVE_GAS_LIMIT);
            MSpellStakingSpoke(stakingSpoke).setTrustedRemote(LayerZeroChainId.Arbitrum, trustedRemote);
        }

        vm.stopBroadcast();

        return (timelock, tx.origin, MSpellStakingHub(stakingHub), MSpellStakingSpoke(stakingSpoke));
    }

    function _deployProxies() internal {
        governor = SpellGovernor(payable(deployUsingCreate3("SpellGovernor", GOVERNOR_SALT, LibClone.initCodeERC1967(governorImpl))));
        if (governor.initializedVersion() < 1) {
            governor.initialize(MSpellStakingHub(stakingHub), TimelockControllerUpgradeable(payable(timelock)), tx.origin);

            if (governor.owner() != tx.origin) {
                revert("owner should be the deployer");
            }
        }

        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);

        proposers[0] = address(governor);
        executors[0] = address(0); // anyone is allowed to execute on the timelock

        timelock = SpellTimelock(payable(deployUsingCreate3("SpellTimelock", TIMELOCK_SALT, LibClone.initCodeERC1967(timelockImpl))));
        if (timelock.initializedVersion() < 1) {
            timelock.initialize(2 days, proposers, executors, tx.origin);

            if (timelock.owner() != tx.origin) {
                revert("owner should be the deployer");
            }
        }

        if (!testing()) {
            /// @note should be done manually once it's all tested and ready to go
            //address safe = toolkit.getAddress(block.chainid, "safe.ops");
            //SpellTimelock _tl = SpellTimelock(payable(timelock));
            //_tl.revokeRole(_tl.DEFAULT_ADMIN_ROLE(), tx.origin);
            //governor.transferOwnership(timelock);
        }
    }

    function _deployImplementations() internal {
        // Timelock
        timelockImpl = deploy("SpellTimelockImpl", "SpellTimelock.sol:SpellTimelock", "");

        // Governance
        governorImpl = deploy("SpellGovernorImpl", "SpellGovernor.sol:SpellGovernor", "");
    }
}
