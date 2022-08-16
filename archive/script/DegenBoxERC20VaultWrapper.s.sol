// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "BoringSolidity/interfaces/IERC20.sol";
import "periphery/DegenBoxERC20VaultWrapper.sol";
import "forge-std/Script.sol";
import "utils/BaseScript.sol";
import "interfaces/IBentoBoxV1.sol";
import "interfaces/IERC20Vault.sol";

contract DegenBoxERC20VaultWrapperScript is BaseScript {
    function run() public {
        vm.startBroadcast();

        new DegenBoxERC20VaultWrapper();

        vm.stopBroadcast();
    }
}
