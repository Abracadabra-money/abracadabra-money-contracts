// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "lenses/MarketLens.sol";

contract MarketLensScript is BaseScript {
    function deploy() public returns (MarketLens lens) {
        vm.startBroadcast();

        lens = new MarketLens{salt: bytes32(bytes("MarketLens.s.sol-20230406-v6"))}();

        vm.stopBroadcast();
    }
}
