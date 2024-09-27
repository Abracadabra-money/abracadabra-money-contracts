// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {TokenLocker} from "/periphery/TokenLocker.sol";
import {IOwnableOperators} from "/interfaces/IOwnableOperators.sol";
import {MintableBurnableUpgradeableERC20} from "/tokens/MintableBurnableUpgradeableERC20.sol";
import {TokenLocker} from "/periphery/TokenLocker.sol";

bytes32 constant BSPELL_SALT = keccak256(bytes("bSpell-1727108300"));
bytes32 constant BSPELL_LOCKER_SALT = keccak256(bytes("bSpellLocker-1727108300"));

contract BoundSpellScript is BaseScript {
    function deploy() public returns (TokenLocker bSpellLocker) {
        vm.startBroadcast();

        address bspell = address(
            deployUpgradeableUsingCreate3(
                "BSPELL",
                BSPELL_SALT,
                "MintableBurnableUpgradeableERC20.sol:MintableBurnableUpgradeableERC20",
                "",
                abi.encodeCall(MintableBurnableUpgradeableERC20.initialize, ("boundSPELL", "bSPELL", 18, tx.origin))
            )
        );

        if (block.chainid == ChainId.Arbitrum) {
            address spell = toolkit.getAddress("spellV2");

            bSpellLocker = TokenLocker(
                deployUpgradeableUsingCreate3(
                    "BSPELLLocker",
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
                //IOwnableOperators(address(bSpellLocker)).transferOwnership(safe);
            }
        }

        if (!testing()) {
            //address safe = toolkit.getAddress("safe.ops");
            //IOwnableOperators(bspell).transferOwnership(safe);
        }

        vm.stopBroadcast();
    }
}
