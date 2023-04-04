// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "periphery/RepayHelper.sol";

contract RepayHelperScript is BaseScript {
    function run() public returns (RepayHelper helper) {
        IERC20 mim = IERC20(constants.getAddress("mainnet.mim"));

        vm.startBroadcast();

        // Dummy deployment example
        helper = new RepayHelper(mim);

        vm.stopBroadcast();
    }
}
