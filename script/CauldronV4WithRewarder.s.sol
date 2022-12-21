// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "utils/BaseScript.sol";
import "cauldrons/CauldronV4WithRewarder.sol";
import "utils/CauldronLib.sol";
import "oracles/ProxyOracle.sol";

contract CauldronV4WithRewarderScript is BaseScript {
    function run() public returns (CauldronV4WithRewarder masterContract, CauldronV4WithRewarder cauldron) {
        
        if (block.chainid == ChainId.Arbitrum) {
            startBroadcast();
            
            IERC20 mim = IERC20(constants.getAddress("arbitrum.mim"));
            address safe = constants.getAddress("arbitrum.safe.ops");
            IBentoBoxV1 degenBox = IBentoBoxV1(constants.getAddress("arbitrum.degenBox"));

            masterContract = new CauldronV4WithRewarder(degenBox, mim);

            cauldron = CauldronV4WithRewarder(address(CauldronLib.deployCauldronV4(
                degenBox,
                address(masterContract),
                IERC20(0x3477Df28ce70Cecf61fFfa7a95be4BEC3B3c7e75),
                ProxyOracle(0x0E1eA2269D6e22DfEEbce7b0A4c6c3d415b5bC85),
                "",
                7500, // 75% ltv
                0, // 0% interests
                0, // 0% opening
                750 // 7.5% liquidation
            )));

            if (!testing) {
                masterContract.transferOwnership(safe, true, false);
            }

            stopBroadcast();
        }
    }
}
