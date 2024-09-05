// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Vm, VmSafe} from "forge-std/Vm.sol";

struct PrankState {
    bool restorePrank;
    address previousPrank;
}

library TestingLib {
    Vm constant vm = Vm(address(bytes20(uint160(uint256(keccak256("hevm cheat code"))))));

    function safeStartPrank(address account) internal returns (PrankState memory prankState) {
        (VmSafe.CallerMode callerMode, address previousPrank, ) = vm.readCallers();
        prankState.restorePrank = callerMode == VmSafe.CallerMode.RecurrentPrank;
        prankState.previousPrank = previousPrank;
        vm.startPrank(account);
    }

    function safeEndPrank(PrankState memory state) internal {
        vm.stopPrank();
        if (state.restorePrank) {
            vm.startPrank(state.previousPrank);
        }
    }
}
