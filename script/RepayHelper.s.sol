// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "periphery/RepayHelper.sol";

contract RepayHelperScript is BaseScript {
    function deploy() public returns (RepayHelper helper) {
        IERC20 mim = IERC20(toolkit.getAddress("mainnet.mim"));

        vm.startBroadcast();
        helper = new RepayHelper(mim);
        vm.stopBroadcast();
    }
}
