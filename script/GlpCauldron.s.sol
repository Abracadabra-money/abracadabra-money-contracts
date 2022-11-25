// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "utils/BaseScript.sol";
import "cauldrons/CauldronV4.sol";
import "periphery/DegenBoxOwner.sol";
import "utils/CauldronLib.sol";
import "oracles/ProxyOracle.sol";
import "periphery/CauldronOwner.sol";
import "interfaces/IGmxRewardRouterV2.sol";
import "tokens/GmxGlpWrapper.sol";
import "periphery/GmxGlpRewardHandler.sol";
import "periphery/MimCauldronDistributor.sol";

contract GlpCauldronScript is BaseScript {
    function run()
        public
        returns (
            CauldronV4 masterContract,
            DegenBoxOwner degenBoxOwner,
            ICauldronV4 cauldron,
            ProxyOracle oracle,
            GmxGlpWrapper wrapper,
            MimCauldronDistributor mimDistributor
        )
    {
        vm.startBroadcast();

        if (block.chainid == ChainId.Mainnet) {
            IBentoBoxV1 degenBox = IBentoBoxV1(constants.getAddress("mainnet.degenBox"));
            masterContract = new CauldronV4(degenBox, IERC20(constants.getAddress("mainnet.mim")));
            degenBoxOwner = new DegenBoxOwner();
            degenBoxOwner.setDegenBox(degenBox);
        }

        if (block.chainid == ChainId.Arbitrum) {
            address safe = constants.getAddress("arbitrum.safe.main");
            oracle = ProxyOracle(0x0E1eA2269D6e22DfEEbce7b0A4c6c3d415b5bC85);
            IBentoBoxV1 degenBox = IBentoBoxV1(constants.getAddress("arbitrum.degenBox"));
            masterContract = new CauldronV4(degenBox, IERC20(constants.getAddress("arbitrum.mim")));
            degenBoxOwner = new DegenBoxOwner();
            degenBoxOwner.setDegenBox(degenBox);

            IGmxRewardRouterV2 rewardRouterV2 = IGmxRewardRouterV2(constants.getAddress("arbitrum.gmx.rewardRouterV2"));
            IERC20 mim = IERC20(constants.getAddress("arbitrum.mim"));
            CauldronOwner owner = new CauldronOwner(safe, ERC20(address(mim)));
            CauldronV4 cauldronV4MC = new CauldronV4(degenBox, mim);

            IERC20 sGlp = IERC20(constants.getAddress("arbitrum.gmx.sGLP"));
            wrapper = new GmxGlpWrapper(sGlp, "abra wrapped sGlp", "abra-wsGlp", address(degenBox));
            GmxGlpRewardHandler rewardHandler = new GmxGlpRewardHandler();

            wrapper.setRewardHandler(address(rewardHandler));

            cauldron = CauldronLib.deployCauldronV4(
                degenBox,
                address(cauldronV4MC),
                wrapper,
                oracle,
                "",
                7500, // 75% ltv
                200, // 2% interests
                50, // 0.5% opening
                750 // 7.5% liquidation
            );

            mimDistributor = new MimCauldronDistributor(ERC20(address(mim)), cauldron);

            GmxGlpRewardHandler(address(wrapper)).setFeeParameters(safe, 0);
            GmxGlpRewardHandler(address(wrapper)).setSwapper(constants.getAddress("arbitrum.aggregators.zeroXExchangProxy"));
            GmxGlpRewardHandler(address(wrapper)).setRewardRouter(rewardRouterV2);
            GmxGlpRewardHandler(address(wrapper)).setRewardTokenEnabled(IERC20(constants.getAddress("arbitrum.weth")), true);
            GmxGlpRewardHandler(address(wrapper)).setRewardTokenEnabled(IERC20(constants.getAddress("arbitrum.gmx.gmx")), true);
            GmxGlpRewardHandler(address(wrapper)).setSwappingTokenOutEnabled(IERC20(constants.getAddress("arbitrum.mim")), true);
            GmxGlpRewardHandler(address(wrapper)).setAllowedSwappingRecipient(address(mimDistributor), true);

            // Only when deploying live
            if (!testing) {
                owner.setOperator(safe, true);
                cauldronV4MC.setFeeTo(safe);
                
                owner.transferOwnership(safe, true, false);
                cauldronV4MC.transferOwnership(address(owner), true, false);
                mimDistributor.transferOwnership(safe, true, false);
                degenBoxOwner.transferOwnership(safe, true, false);
                masterContract.transferOwnership(safe, true, false);
                wrapper.transferOwnership(safe, true, false);
            }
        }

        vm.stopBroadcast();
    }
}
