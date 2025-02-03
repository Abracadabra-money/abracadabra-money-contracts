// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";

contract SpellMigratorScript is BaseScript {
    function deploy() public {
        vm.startBroadcast();
        deploy(
            "SpellMigrator",
            "TokenMigrator.sol:TokenMigrator",
            abi.encode(toolkit.getAddress("spell"), toolkit.getAddress("spellV2"), tx.origin)
        );
        vm.stopBroadcast();
    }
}
