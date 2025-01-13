// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {Timelock} from "/periphery/Timelock.sol";

contract TimelockScript is BaseScript {
    bytes32 constant TIMELOCK_SALT = keccak256(bytes("Timelock-1729617806"));

    function deploy() public {
        vm.startBroadcast();

        address opsSafe = toolkit.getAddress("safe.ops");
        address mainSafe = toolkit.getAddress("safe.main");

        address[] memory proposers = new address[](2);
        address[] memory executors = new address[](1);

        proposers[0] = address(opsSafe);
        executors[0] = address(0); // anyone is allowed to execute on the timelock

        deployUpgradeableUsingCreate3(
            "Timelock",
            TIMELOCK_SALT,
            "Timelock.sol:Timelock",
            "",
            abi.encodeCall(Timelock.initialize, (2 days, proposers, executors, mainSafe))
        );
        vm.stopBroadcast();
    }
}
