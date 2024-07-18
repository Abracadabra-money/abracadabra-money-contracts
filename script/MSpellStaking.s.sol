// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {MSpellStaking} from "/staking/MSpellStaking.sol";

contract MSpellStakingScript is BaseScript {
    function deploy() public returns (MSpellStaking staking) {
        vm.startBroadcast();

        if (block.chainid == ChainId.Arbitrum) {
            revert("Arbitrum is not supported.");
        }

        address mim = toolkit.getAddress(block.chainid, "mim");
        address spell = toolkit.getAddress(block.chainid, "spell");
        address safe = toolkit.getAddress(block.chainid, "safe.ops");

        staking = MSpellStaking(deploy("MSpellStakingV2", "MSpellStaking.sol:MSpellStaking", abi.encode(mim, spell, safe)));

        vm.stopBroadcast();
    }
}
