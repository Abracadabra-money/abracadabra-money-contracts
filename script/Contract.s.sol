// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "src/Contract.sol";
import "utils/BaseScript.sol";

contract ContractScript is BaseScript {
    function run() public returns (Contract) {
        address mim = this.getAddress("mainnet.mim");
        address xMerlin = this.getAddress("xMerlin");

        vm.startBroadcast();
        Contract c = new Contract(mim);

        if (!testing) {
            c.setOwner(xMerlin);
        }

        vm.stopBroadcast();

        return (c);
    }
}
