// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "interfaces/IBentoBoxV1.sol";
import "BoringSolidity/ERC20.sol";
import "utils/BaseScript.sol";
import "periphery/CauldronOwner.sol";
import "cauldrons/CauldronV4.sol";

contract CauldronV4Script is BaseScript {
    function deploy() public {
        IBentoBoxV1 degenBox = IBentoBoxV1(toolkit.getAddress(block.chainid, "degenBox"));
        address safe = toolkit.getAddress(block.chainid, "safe.ops");
        ERC20 mim = ERC20(toolkit.getAddress(block.chainid, "mim"));

        vm.startBroadcast();
        CauldronOwner cauldronOwner = CauldronOwner(deploy("CauldronOwner", "CauldronOwner.sol:CauldronOwner", abi.encode(safe, mim)));
        CauldronV4 cauldronV4MC = CauldronV4(deploy("CauldronV4", "CauldronV4.sol:CauldronV4", abi.encode(degenBox, mim)));

        if (!testing()) {
            if (cauldronOwner.owner() == tx.origin) {
                if (!cauldronOwner.operators(safe)) {
                    cauldronOwner.setOperator(safe, true);
                }
                cauldronOwner.transferOwnership(safe, true, false);
            }

            if (cauldronV4MC.owner() == tx.origin) {
                if (cauldronV4MC.feeTo() != safe) {
                    cauldronV4MC.setFeeTo(safe);
                }
                cauldronV4MC.transferOwnership(address(safe));
            }
        }
        vm.stopBroadcast();
    }
}
