// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "src/Contract.sol";
import "utils/BaseScript.sol";

contract ContractScript is BaseScript {
    function run() public returns (Contract, DegenBox) {
        address mim = constants.getAddress("mainnet.mim");
        address weth = constants.getAddress("mainnet.weth");
        address xMerlin = constants.getAddress("xMerlin");

        vm.startBroadcast();
        Contract c = new Contract(mim);
        DegenBox d = deploy.deployDegenBox(weth);

        if (!testing) {
            c.setOwner(xMerlin);
            d.transferOwnership(xMerlin, true, false);
        }

        vm.stopBroadcast();

        return (c, d);
    }
}
