// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {TokenLocker} from "/periphery/TokenLocker.sol";
import {IOwnableOperators} from "/interfaces/IOwnableOperators.sol";

contract BoundSpellLockerScript is BaseScript {
    bytes32 constant BSPELL_SALT = keccak256(bytes("bSpell-1716556948"));
    bytes32 constant BSPELL_LOCKER_SALT = keccak256(bytes("bSpellLocker-1716556948"));

    function deploy() public returns (TokenLocker bSpellLocker) {
        vm.startBroadcast();
        address spell = toolkit.getAddress(block.chainid, "spell");
        address safe = toolkit.getAddress("safe.ops");

        address bspell = address(
            deployUsingCreate3(
                "bSPELL",
                BSPELL_SALT,
                "MintableBurnableERC20.sol:MintableBurnableERC20",
                abi.encode(tx.origin, "boundSPELL", "bSPELL", 18)
            )
        );
        bSpellLocker = TokenLocker(
            deployUsingCreate3("bSpellLocker", BSPELL_LOCKER_SALT, "TokenLocker.sol:TokenLocker", abi.encode(bspell, spell, 13 weeks, tx.origin))
        );

        IOwnableOperators(bspell).setOperator(address(bSpellLocker), true);

        if (!testing()) {
            IOwnableOperators(bspell).transferOwnership(safe);
            IOwnableOperators(address(bSpellLocker)).transferOwnership(safe);
        }

        vm.stopBroadcast();
    }
}
