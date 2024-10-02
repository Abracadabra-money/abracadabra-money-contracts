// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@BoringSolidity/interfaces/IERC20.sol";
import "utils/BaseScript.sol";
import "utils/CauldronDeployLib.sol";
import "/oracles/ProxyOracle.sol";
import "/cauldrons/PrivilegedCauldronV4.sol";
import "/cauldrons/PrivilegedCheckpointCauldronV4.sol";

contract CheckpointCauldronV4Script is BaseScript {
    function deploy() public {
        IBentoBoxV1 degenBox = IBentoBoxV1(toolkit.getAddress("degenBox"));
        address safe = toolkit.getAddress("safe.ops");
        address feeWithdrawer = toolkit.getAddress("cauldronFeeWithdrawer");
        IERC20 mim = IERC20(toolkit.getAddress("mim"));

        vm.startBroadcast();

        PrivilegedCauldronV4 mc = PrivilegedCauldronV4(
            deploy("PrivilegedCauldronV4", "PrivilegedCauldronV4.sol:PrivilegedCauldronV4", abi.encode(degenBox, mim))
        );
        PrivilegedCheckpointCauldronV4 mc2 = PrivilegedCheckpointCauldronV4(
            deploy(
                "PrivilegedCheckpointCauldronV4",
                "PrivilegedCheckpointCauldronV4.sol:PrivilegedCheckpointCauldronV4",
                abi.encode(degenBox, mim, tx.origin)
            )
        );

        if (!testing()) {
            mc.setFeeTo(feeWithdrawer);
            mc2.setFeeTo(safe);

            mc.transferOwnership(address(safe));
            mc2.transferOwnership(address(safe));
        }

        vm.stopBroadcast();
    }
}
