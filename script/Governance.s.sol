// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {ERC1967Factory} from "solady/utils/ERC1967Factory.sol";
import {SpellTimelock} from "/governance/SpellTimelock.sol";
import {MSpellStaking} from "/staking/MSpellStaking.sol";

contract GovernanceScript is BaseScript {
    ERC1967Factory factory;

    // salts
    bytes32 timelockSalt;
    bytes32 governanceSalt;

    // Proxies
    address timelock;
    address governance;

    // Implementations
    address timelockImpl;
    address governanceImpl;

    // Voting staking
    MSpellStaking staking;

    function deploy() public returns (SpellTimelock, address timelockOwner, MSpellStaking) {
        factory = ERC1967Factory(toolkit.getAddress(ChainId.All, "ERC1967Factory"));
        timelockSalt = generateERC1967FactorySalt(tx.origin, "Timelock-1");

        vm.startBroadcast();

        _deployImplementations();
        _deployProxies();

        vm.stopBroadcast();

        return (SpellTimelock(payable(timelock)), tx.origin, staking);
    }

    function _deployFactory() internal {
        deployUsingCreate3("ERC1967Factory", keccak256(bytes("ERC1967Factory-2")), "ERC1967Factory.sol:ERC1967Factory", "");
    }

    function _deployProxies() internal {
        governance = factory.deployDeterministicAndCall(
            governanceImpl,
            tx.origin,
            governanceSalt,
            abi.encodeCall(SpellTimelock.initialize, (2 days, new address[](0), new address[](0), tx.origin))
        );

        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);

        proposers[0] = governance;
        executors[0] = address(0); // anyone is allowed to execute on the timelock

        timelock = factory.deployDeterministicAndCall(
            timelockImpl,
            tx.origin,
            timelockSalt,
            abi.encodeCall(SpellTimelock.initialize, (2 days, proposers, executors, tx.origin))
        );

        if (!testing()) {
            SpellTimelock _tl = SpellTimelock(payable(timelock));
            _tl.revokeRole(_tl.DEFAULT_ADMIN_ROLE(), tx.origin);
        }
    }

    function _deployImplementations() internal {
        // Timelock
        timelockImpl = deploy("SpellTimelockImpl", "SpellTimelock.sol:SpellTimelock", "");
    }
}
