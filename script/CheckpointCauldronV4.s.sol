// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "oracles/ProxyOracle.sol";
import "utils/BaseScript.sol";
import "cauldrons/CheckpointCauldronV4.sol";
import "utils/CauldronDeployLib.sol";

contract CheckpointCauldronV4Script is BaseScript {
    function deploy() public {
        IBentoBoxV1 degenBox = IBentoBoxV1(constants.getAddress(block.chainid, "degenBox"));
        address safe = constants.getAddress(block.chainid, "safe.ops");
        address feeWithdrawer = constants.getAddress(block.chainid, "cauldronFeeWithdrawer");
        ERC20 mim = ERC20(constants.getAddress(block.chainid, "mim"));

        startBroadcast();

        CheckpointCauldronV4 mc = new CheckpointCauldronV4(degenBox, mim);

        if (!testing) {
            mc.setFeeTo(feeWithdrawer);
            mc.transferOwnership(address(safe), true, false);
        }

        stopBroadcast();
    }
}
