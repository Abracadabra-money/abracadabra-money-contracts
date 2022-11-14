// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "oracles/ProxyOracle.sol";
import "utils/BaseScript.sol";
import "utils/CauldronLib.sol";
import "periphery/CauldronOwner.sol";

contract FTTCauldron is BaseScript {
    function run() public {
        IBentoBoxV1 degenBox = IBentoBoxV1(constants.getAddress("mainnet.degenBox"));
        ERC20 mim = ERC20(constants.getAddress("mainnet.mim"));
        address treasury = constants.getAddress("mainnet.mimTreasury");
        address xMerlin = constants.getAddress("xMerlin");

        vm.startBroadcast();

        ProxyOracle oracle = ProxyOracle(0x96a5B3B70294BfAAb842d498C07d5aed581395A0);
        CauldronOwner owner = new CauldronOwner(treasury, mim);
        CauldronV4 cauldronV4MC = new CauldronV4(degenBox, mim);

        CauldronLib.deployCauldronV4(
            degenBox,
            address(cauldronV4MC),
            IERC20(constants.getAddress("mainnet.ftt")),
            oracle,
            "",
            6500, // 65% ltv
            200, // 2% interests
            50, // 0.5% opening
            750 // 7.5% liquidation
        );

        // Only when deploying live
        if (!testing) {
            owner.setOperator(xMerlin, true);
            owner.transferOwnership(xMerlin, true, false);
            cauldronV4MC.setFeeTo(treasury);
            cauldronV4MC.transferOwnership(address(owner), true, false);
        }

        vm.stopBroadcast();
    }
}
