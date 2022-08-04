// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "/Contract.sol";
import "utils/BaseScript.sol";

contract ContractScript is BaseScript {
    function run() public returns (Contract, DegenBox) {
        address mim = constants.getAddress("mainnet.mim");
        address weth = constants.getAddress("mainnet.weth");
        address xMerlin = constants.getAddress("xMerlin");

        vm.startBroadcast();

        Contract c = new Contract(mim);
        DegenBox degenBox = deployDegenBox(weth);
        CauldronV3_2 masterContract = deployCauldronV3MasterContract(address(degenBox), mim);
        degenBox.whitelistMasterContract(address(masterContract), true);

        deployCauldronV3(
            address(degenBox),
            address(masterContract),
            weth,
            0x6C86AdB5696d2632973109a337a50EF7bdc48fF1,
            "",
            8000, // 80%
            250, // 2.5%
            100, // 1%
            900 // 8%
        );

        if (!testing) {
            c.setOwner(xMerlin);
            degenBox.transferOwnership(xMerlin, true, false);
        }

        vm.stopBroadcast();

        return (c, degenBox);
    }
}
