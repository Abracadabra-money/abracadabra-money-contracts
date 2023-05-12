// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/LegacyBaseScript.sol";
import "periphery/RepayHelper.sol";

contract RepayHelperScript is LegacyBaseScript {
    function run() public returns (RepayHelper helper) {
        IERC20 mim = IERC20(constants.getAddress("mainnet.mim"));

        startBroadcast();
        helper = new RepayHelper(mim);
        stopBroadcast();
    }
}
