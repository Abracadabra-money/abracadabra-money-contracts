// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {TokenLocker} from "/periphery/TokenLocker.sol";
import {IOwnableOperators} from "/interfaces/IOwnableOperators.sol";
import {MintableBurnableUpgradeableERC20} from "/tokens/MintableBurnableUpgradeableERC20.sol";
import {TokenLocker} from "/periphery/TokenLocker.sol";

bytes32 constant BSPELL_SALT = keccak256(bytes("bSpell-1727108299"));
bytes32 constant BSPELL_LOCKER_SALT = keccak256(bytes("bSpellLocker-1727108299"));

contract BoundSpellScript is BaseScript {
    function deploy() public returns (TokenLocker bSpellLocker) {
        if (block.chainid != ChainId.Arbitrum) {
            revert("BoundSpellLockerScript: Arbitrum only");
        }

        vm.startBroadcast();

        address bspell = address(
            deployUpgradeableUsingCreate3(
                "BoundSPELL",
                BSPELL_SALT,
                "MintableBurnableUpgradeableERC20.sol:MintableBurnableUpgradeableERC20",
                "",
                abi.encodeCall(MintableBurnableUpgradeableERC20.initialize, ("boundSPELL", "bSPELL", 18, tx.origin))
            )
        );

        address spell = toolkit.getAddress("spellV2");

        bSpellLocker = TokenLocker(
            deployUpgradeableUsingCreate3(
                "BoundSpellLocker",
                BSPELL_LOCKER_SALT,
                "TokenLocker.sol:TokenLocker",
                abi.encode(bspell, spell, 13 weeks),
                abi.encodeCall(TokenLocker.initialize, (tx.origin))
            )
        );

        if (IOwnableOperators(bspell).owner() == tx.origin) {
            IOwnableOperators(bspell).setOperator(address(bSpellLocker), true);
        }

        if (!testing()) {
            //address safe = toolkit.getAddress("safe.ops");
            //IOwnableOperators(bspell).transferOwnership(safe);
            //IOwnableOperators(address(bSpellLocker)).transferOwnership(safe);
        }

        vm.stopBroadcast();
    }
}
