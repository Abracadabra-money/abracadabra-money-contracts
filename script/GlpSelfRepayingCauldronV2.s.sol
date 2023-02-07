// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "utils/BaseScript.sol";
import "utils/CauldronDeployLib.sol";
import "cauldrons/CauldronV4WithRewarder.sol";
import "interfaces/ICauldronV4WithRewarder.sol";
import "oracles/ProxyOracle.sol";
import "periphery/MimCauldronDistributor.sol";
import "periphery/CauldronRewarder.sol";

contract GlpSelfRepayingCauldronV2Script is BaseScript {
    function run()
        public
        returns (
            ICauldronV4WithRewarder cauldron,
            ICauldronRewarder rewarder,
            MimCauldronDistributor distributor
        )
    {
        if (block.chainid == ChainId.Arbitrum) {
            address safe = constants.getAddress("arbitrum.safe.ops");
            ERC20 mim = ERC20(constants.getAddress("arbitrum.mim"));
            IBentoBoxV1 degenBox = IBentoBoxV1(constants.getAddress("arbitrum.degenBox"));

            startBroadcast();

            CauldronV4WithRewarder masterContract = new CauldronV4WithRewarder(degenBox, mim);

            cauldron = ICauldronV4WithRewarder(
                address(
                    CauldronDeployLib.deployCauldronV4(
                        degenBox,
                        address(masterContract),
                        IERC20(0x3477Df28ce70Cecf61fFfa7a95be4BEC3B3c7e75),
                        ProxyOracle(0x0E1eA2269D6e22DfEEbce7b0A4c6c3d415b5bC85),
                        "",
                        7500, // 75% ltv
                        0, // 0% interests
                        0, // 0% opening
                        750 // 7.5% liquidation
                    )
                )
            );

            rewarder = new CauldronRewarder(mim, cauldron);

            cauldron.setRewarder(rewarder);

            distributor = new MimCauldronDistributor(mim, safe, CauldronLib.getInterestPerSecond(1000));

            if (!testing) {
                masterContract.transferOwnership(safe, true, false);

                // GLP cauldron 10% target apy, up to
                distributor.setCauldronParameters(cauldron, 1000, 1000 ether, rewarder);
                distributor.transferOwnership(safe, true, false);
            }

            stopBroadcast();
        }
    }
}
