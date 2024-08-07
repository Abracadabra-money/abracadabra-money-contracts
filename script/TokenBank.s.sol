// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {TokenBank} from "/periphery/TokenBank.sol";
import {IOwnableOperators} from "/interfaces/IOwnableOperators.sol";

contract TokenBankScript is BaseScript {
    bytes32 constant OSPELL_SALT = keccak256(bytes("OSpell-1716556947"));
    bytes32 constant OSPELL_BANK_SALT = keccak256(bytes("OSpellBank-1716556947"));

    function deploy() public returns (TokenBank oSpellBank) {
        vm.startBroadcast();
        address spell = toolkit.getAddress(block.chainid, "spell");
        address safe = toolkit.getAddress("safe.ops");

        address ospell = address(
            deployUsingCreate3(
                "OSpell",
                OSPELL_SALT,
                "MintableBurnableERC20.sol:MintableBurnableERC20",
                abi.encode(tx.origin, "OSPELL", "OSPELL", 18)
            )
        );
        oSpellBank = TokenBank(
            deployUsingCreate3("OSpellBank", OSPELL_BANK_SALT, "TokenBank.sol:TokenBank", abi.encode(ospell, spell, 13 weeks, tx.origin))
        );

        IOwnableOperators(ospell).setOperator(address(oSpellBank), true);

        if (!testing()) {
            IOwnableOperators(ospell).transferOwnership(safe);
            IOwnableOperators(address(oSpellBank)).transferOwnership(safe);
        }

        vm.stopBroadcast();
    }
}
