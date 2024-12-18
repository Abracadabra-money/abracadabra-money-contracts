// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {ISwapperV2} from "/interfaces/ISwapperV2.sol";

contract SDEUSDSwapperScript is BaseScript {
    function deploy() public returns (ISwapperV2 swapper) {
        vm.startBroadcast();
        swapper = ISwapperV2(deploy("SDEUSDSwapper", "SDEUSDSwapper.sol:SDEUSDSwapper", ""));
        vm.stopBroadcast();
    }
}