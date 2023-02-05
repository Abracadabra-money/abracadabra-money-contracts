// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "cauldrons/CauldronV4.sol";
import "utils/CauldronLib.sol";
import "oracles/ProxyOracle.sol";
import "periphery/CauldronOwner.sol";
import "interfaces/IGmxRewardRouterV2.sol";
import "interfaces/IGmxGlpRewardRouter.sol";
import "interfaces/IWETH.sol";
import "tokens/MagicGlp.sol";
import "periphery/MagicGlpRewardHandler.sol";
import "periphery/DegenBoxERC4626Wrapper.sol";
import "periphery/MagicGlpHarvestor.sol";
import "oracles/MagicGlpOracle.sol";
import "swappers/MagicGlpSwapper.sol";
import "swappers/MagicGlpLevSwapper.sol";

contract MagicGlpCauldronScript is BaseScript {
    function run()
        public
        returns (
            ICauldronV4 cauldron,
            MagicGlp magicGlp,
            MagicGlpHarvestor harvestor,
            ProxyOracle oracle
        )
    {
        if (block.chainid == ChainId.Arbitrum) {
            address safe = constants.getAddress("arbitrum.safe.ops");
            address sGlp = constants.getAddress("arbitrum.gmx.sGLP");
            address degenBox = constants.getAddress("arbitrum.degenBox");
            address masterContract = constants.getAddress("arbitrum.cauldronV4");
            address weth = constants.getAddress("arbitrum.weth");
            address glpManager = constants.getAddress("arbitrum.gmx.glpManager");
            address rewardRouterV2 = constants.getAddress("arbitrum.gmx.rewardRouterV2");
            address glpRewardRouter = constants.getAddress("arbitrum.gmx.glpRewardRouter");

            startBroadcast();

            magicGlp = new MagicGlp(ERC20(sGlp), "magicGLP", "mGLP");
            MagicGlpOracle oracleImpl = new MagicGlpOracle(
                IGmxGlpManager(glpManager),
                IERC20(constants.getAddress("arbitrum.gmx.glp")),
                IERC4626(magicGlp)
            );

            oracle = new ProxyOracle();
            oracle.changeOracleImplementation(IOracle(oracleImpl));
            cauldron = CauldronLib.deployCauldronV4(
                IBentoBoxV1(degenBox),
                masterContract,
                magicGlp,
                oracle,
                "",
                7500, // 75% ltv
                600, // 6% interests
                0, // 0% opening
                750 // 7.5% liquidation
            );

            // Periphery contract used to atomically wrap and deposit to degenbox
            new DegenBoxERC4626Wrapper(IBentoBoxV1(degenBox), magicGlp);

            MagicGlpRewardHandler rewardHandler = new MagicGlpRewardHandler();
            rewardHandler.transferOwnership(address(0), true, true); // owner is only from the sGlp wrapper
            magicGlp.setRewardHandler(address(rewardHandler));

            // Use to facilitate collecting and swapping rewards to the distributor & distribute
            harvestor = new MagicGlpHarvestor(
                IWETH(weth),
                IGmxRewardRouterV2(rewardRouterV2),
                IGmxGlpRewardRouter(glpRewardRouter),
                IMagicGlpRewardHandler(address(magicGlp))
            );
            harvestor.setOperator(constants.getAddress("arbitrum.safe.devOps.gelatoProxy"), true);
            harvestor.setFeeParameters(safe, 100); // 1% fee

            magicGlp.setStrategyExecutor(address(harvestor), true);

            MagicGlpRewardHandler(address(magicGlp)).setRewardRouter(IGmxRewardRouterV2(rewardRouterV2));
            MagicGlpRewardHandler(address(magicGlp)).setTokenAllowance(IERC20(weth), address(harvestor), type(uint256).max);

            // Only when deploying live
            if (!testing) {
                magicGlp.transferOwnership(safe, true, false);
                harvestor.transferOwnership(safe, true, false);
                oracle.transferOwnership(safe, true, false);

                // mint some initial MagicGlp
                ERC20(sGlp).approve(address(magicGlp), ERC20(sGlp).balanceOf(tx.origin));
                magicGlp.deposit(ERC20(sGlp).balanceOf(tx.origin), safe);
            }

            stopBroadcast();
        } else {
            revert("chain not supported");
        }
    }
}
