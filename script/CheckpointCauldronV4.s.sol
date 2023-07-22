// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "oracles/ProxyOracle.sol";
import "cauldrons/CheckpointCauldronV4.sol";
import "utils/CauldronDeployLib.sol";

contract CheckpointCauldronV4Script is BaseScript {
    function deploy() public {
        IBentoBoxV1 degenBox = IBentoBoxV1(toolkit.getAddress("degenBox", block.chainid));
        address safe = toolkit.getAddress("safe.ops", block.chainid);
        address feeWithdrawer = toolkit.getAddress("cauldronFeeWithdrawer", block.chainid);
        ERC20 mim = ERC20(toolkit.getAddress("mim", block.chainid));

        vm.startBroadcast();

        CheckpointCauldronV4 mc = new CheckpointCauldronV4(degenBox, mim);
        WhitelistedCheckpointCauldronV4 mc2 = new WhitelistedCheckpointCauldronV4(degenBox, mim);

        if (!testing()) {
            mc.setFeeTo(feeWithdrawer);
            mc2.setFeeTo(safe);

            mc.transferOwnership(address(safe), true, false);
            mc2.transferOwnership(address(safe), true, false);
        }

        vm.stopBroadcast();
    }
}
