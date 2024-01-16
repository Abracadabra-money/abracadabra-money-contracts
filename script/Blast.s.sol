// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";

contract BlastScript is BaseScript {
    function deploy() public returns (address blastBox) {
        vm.startBroadcast();
        blastBox = deploy("DegenBoxBlast", "DegenBoxBlast.sol:DegenBoxBlast", abi.encode(0));
        vm.stopBroadcast();
    }
}
