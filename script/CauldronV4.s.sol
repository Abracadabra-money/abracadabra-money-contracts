// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import "/interfaces/IBentoBoxV1.sol";
import "/cauldrons/CauldronV4.sol";

contract CauldronV4Script is BaseScript {
    bytes32 private constant CAULDRON_SALT = bytes32(keccak256("CauldronV4_1722390626"));

    function deploy() public {
        IBentoBoxV1 degenBox = IBentoBoxV1(toolkit.getAddress("degenBox"));
        address feeTo;

        if (block.chainid == ChainId.Bera) {
            feeTo = toolkit.getAddress("safe.yields"); // TODO: cauldronFeeWithdrawer supporting MIMv2
        } else {
            feeTo = toolkit.getAddress("cauldronFeeWithdrawer");
        }

        address cauldronOwner = toolkit.getAddress("cauldronOwner");
        address mim = toolkit.getAddress("mim");

        vm.startBroadcast();
        CauldronV4 cauldronV4MC = CauldronV4(
            deployUsingCreate3("CauldronV4", CAULDRON_SALT, "CauldronV4.sol:CauldronV4", abi.encode(degenBox, mim, tx.origin))
        );

        if (!testing()) {
            if (cauldronV4MC.owner() == tx.origin) {
                if (cauldronV4MC.feeTo() != feeTo) {
                    cauldronV4MC.setFeeTo(feeTo);
                }
                cauldronV4MC.transferOwnership(cauldronOwner);
            }
        }
        vm.stopBroadcast();
    }
}
