// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "cauldrons/CauldronV4.sol";
import "utils/CauldronDeployLib.sol";
import "oracles/ProxyOracle.sol";
import "periphery/CauldronOwner.sol";
import "interfaces/IGmxRewardRouterV2.sol";
import "interfaces/IGmxGlpRewardRouter.sol";
import {IWETHAlike} from "interfaces/IWETH.sol";
import "tokens/MagicGlp.sol";
import "periphery/MagicGlpRewardHandler.sol";
import "periphery/DegenBoxERC4626Wrapper.sol";
import "periphery/MagicGlpHarvestor.sol";
import "oracles/MagicGlpOracle.sol";
import "swappers/MagicGlpSwapper.sol";
import "swappers/MagicGlpLevSwapper.sol";

contract MagicGlpCauldronScript is BaseScript {
    struct Config {
        address safe;
        address sGlp;
        address degenBox;
        address masterContract;
        address rewardToken;
        address glpManager;
        address rewardRouterV2;
        address glpRewardRouter;
        address gelatoProxy;
        IERC20 glp;
    }

    Config config;

    function run()
        public
        returns (
            ICauldronV4 cauldron,
            MagicGlp magicGlp,
            MagicGlpHarvestor harvestor,
            ProxyOracle oracle
        )
    {
        config.gelatoProxy = constants.getAddress("safe.devOps.gelatoProxy");

        if (block.chainid == ChainId.Arbitrum) {
            config.safe = constants.getAddress("arbitrum.safe.ops");
            config.sGlp = constants.getAddress("arbitrum.gmx.sGLP");
            config.degenBox = constants.getAddress("arbitrum.degenBox");
            config.masterContract = constants.getAddress("arbitrum.cauldronV4");
            config.rewardToken = constants.getAddress("arbitrum.weth");
            config.glpManager = constants.getAddress("arbitrum.gmx.glpManager");
            config.rewardRouterV2 = constants.getAddress("arbitrum.gmx.rewardRouterV2");
            config.glpRewardRouter = constants.getAddress("arbitrum.gmx.glpRewardRouter");
            config.glp = IERC20(constants.getAddress("arbitrum.gmx.glp"));
        } else if (block.chainid == ChainId.Avalanche) {
            config.safe = constants.getAddress("avalanche.safe.ops");
            config.sGlp = constants.getAddress("avalanche.gmx.sGLP");
            config.degenBox = constants.getAddress("avalanche.degenBox");
            config.masterContract = constants.getAddress("avalanche.cauldronV4");
            config.rewardToken = constants.getAddress("avalanche.wavax");
            config.glpManager = constants.getAddress("avalanche.gmx.glpManager");
            config.rewardRouterV2 = constants.getAddress("avalanche.gmx.rewardRouterV2");
            config.glpRewardRouter = constants.getAddress("avalanche.gmx.glpRewardRouter");
            config.glp = IERC20(constants.getAddress("avalanche.gmx.glp"));
        } else {
            revert("chain not supported");
        }
        startBroadcast();

        magicGlp = new MagicGlp(ERC20(config.sGlp), "magicGLP", "mGLP");
        MagicGlpOracle oracleImpl = new MagicGlpOracle(IGmxGlpManager(config.glpManager), config.glp, IERC4626(magicGlp));

        oracle = new ProxyOracle();
        oracle.changeOracleImplementation(IOracle(oracleImpl));
        cauldron = CauldronDeployLib.deployCauldronV4(
            IBentoBoxV1(config.degenBox),
            config.masterContract,
            magicGlp,
            oracle,
            "",
            7500, // 75% ltv
            600, // 6% interests
            0, // 0% opening
            750 // 7.5% liquidation
        );

        // Periphery contract used to atomically wrap and deposit to degenbox
        new DegenBoxERC4626Wrapper(IBentoBoxV1(config.degenBox), magicGlp);

        MagicGlpRewardHandler rewardHandler = new MagicGlpRewardHandler();
        rewardHandler.transferOwnership(address(0), true, true); // owner is only from the sGlp wrapper
        magicGlp.setRewardHandler(address(rewardHandler));

        // Use to facilitate collecting and swapping rewards to the distributor & distribute
        harvestor = new MagicGlpHarvestor(
            IWETHAlike(config.rewardToken),
            IGmxRewardRouterV2(config.rewardRouterV2),
            IGmxGlpRewardRouter(config.glpRewardRouter),
            IMagicGlpRewardHandler(address(magicGlp))
        );
        harvestor.setOperator(config.gelatoProxy, true);
        harvestor.setFeeParameters(config.safe, 100); // 1% fee

        magicGlp.setStrategyExecutor(address(harvestor), true);

        MagicGlpRewardHandler(address(magicGlp)).setRewardRouter(IGmxRewardRouterV2(config.rewardRouterV2));
        MagicGlpRewardHandler(address(magicGlp)).setTokenAllowance(IERC20(config.rewardToken), address(harvestor), type(uint256).max);

        if (!testing) {
            magicGlp.transferOwnership(config.safe, true, false);
            harvestor.transferOwnership(config.safe, true, false);
            oracle.transferOwnership(config.safe, true, false);

            // mint some initial MagicGlp
            ERC20(config.sGlp).approve(address(magicGlp), ERC20(config.sGlp).balanceOf(tx.origin));
            magicGlp.deposit(ERC20(config.sGlp).balanceOf(tx.origin), config.safe);
        }

        stopBroadcast();
    }
}
