// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import "utils/CauldronDeployLib.sol";
import "oracles/ProxyOracle.sol";
import "oracles/MagicVaultOracle.sol";
import "oracles/aggregators/CurveStablePoolAggregator.sol";
import "oracles/aggregators/XF33dAggregator.sol";
import "periphery/DegenBoxERC4626Wrapper.sol";
import "swappers/MagicCurveLpSwapper.sol";
import "swappers/MagicCurveLpLevSwapper.sol";
import "tokens/MagicCurveLp.sol";
import "periphery/MagicCurveLpHarvestor.sol";
import "periphery/MagicCurveLpRewardHandler.sol";
import "tokens/MagicCurveLp.sol";
import "interfaces/ISwapperV2.sol";
import "interfaces/ILevSwapperV2.sol";
import "interfaces/ICurveRewardGauge.sol";
import "interfaces/ICauldronV4.sol";
import "interfaces/IBentoBoxV1.sol";
import "interfaces/ICurvePool.sol";
import "interfaces/IERC4626.sol";
import "interfaces/IAggregator.sol";
import "interfaces/IXF33dMultiAggregator.sol";

contract MagicCurveLpScript is BaseScript {
    using DeployerFunctions for Deployer;

    address safe;
    address pool;
    address exchange;
    IBentoBoxV1 box;

    function deploy() public returns (MagicCurveLp vault, MagicCurveLpHarvestor harvestor) {
        if (block.chainid == ChainId.Kava) {
            return _deployKavaMagicMimUsdt();
        } else {
            revert("Unsupported chain");
        }
    }

    function _deployKavaMagicMimUsdt() private returns (MagicCurveLp vault, MagicCurveLpHarvestor harvestor) {
        pool = toolkit.getAddress(block.chainid, "curve.mimusdt.pool");
        safe = toolkit.getAddress(block.chainid, "safe.ops");
        box = IBentoBoxV1(toolkit.getAddress(block.chainid, "degenBox"));
        exchange = toolkit.getAddress(block.chainid, "aggregators.openocean");

        ICurveRewardGauge gauge = ICurveRewardGauge(toolkit.getAddress(block.chainid, "curve.mimusdt.gauge"));

        vault = MagicCurveLp(
            deployer.deploy_MagicCurveLp("Kava_MagicCurveLp_MIM_USDT", ERC20(pool), "magicCurveLP MIM-USDT", "mCurveLP-MIM-USDT")
        );

        MagicCurveLpRewardHandler rewardHandler = deployer.deploy_MagicCurveLpRewardHandler(
            "Kava_MagicLevelRewardHandler_MIM_USDT_Impl_V1"
        );

        if (vault.rewardHandler() != rewardHandler) {
            vm.broadcast();
            vault.setRewardHandler(rewardHandler);
        }

        if (MagicCurveLpRewardHandler(address(vault)).staking() != gauge) {
            vm.broadcast();
            MagicCurveLpRewardHandler(address(vault)).setStaking(gauge);
        }

        harvestor = deployer.deploy_MagicCurveLpHarvestor(
            "Kava_MagicLevelHarvestor_MIM_USDT_V1",
            IERC20(toolkit.getAddress(block.chainid, "wKava")),
            2, // MIM/USDT pool is 2 coins length
            1, // Provide liquidity using USDT (index: 1)
            vault
        );

        address routerAddress = toolkit.getAddress(block.chainid, "aggregators.openocean");
        if (harvestor.exchangeRouter() != routerAddress) {
            vm.broadcast();
            harvestor.setExchangeRouter(routerAddress);
        }

        if (IERC20(pool).allowance(address(harvestor), address(vault)) != type(uint256).max) {
            vm.broadcast();
            harvestor.setVaultAssetAllowance(type(uint256).max);
        }

        if (harvestor.feeCollector() != safe || harvestor.feeBips() != 100) {
            vm.broadcast();
            harvestor.setFeeParameters(safe, 100); // 1% fee
        }

        if (!vault.operators(address(harvestor))) {
            vm.broadcast();
            vault.setOperator(address(harvestor), true);
        }

        ProxyOracle oracle = ProxyOracle(deployer.deploy_ProxyOracle("Kava_MagicCurveLpProxyOracle_MIM_USDT"));

        IAggregator[] memory aggregators = new IAggregator[](1);

        // USDT/USD coming from arbitrum chainlink oracle
        bytes32 feed = keccak256(abi.encode(uint16(LayerZeroChainId.Arbitrum), toolkit.getAddress(ChainId.Arbitrum, "chainlink.usdt")));
        aggregators[0] = deployer.deploy_XF33dAggregator(
            "Kava_Xf33dAggregator_USDT",
            IXF33dMultiAggregator(toolkit.getAddress(ChainId.All, "XF33dOracle")),
            feed
        );

        CurveStablePoolAggregator aggregator = CurveStablePoolAggregator(
            deployer.deploy_CurveStablePoolAggregator("Kava_Curve_MIM_USDT_Aggregator", ICurvePool(pool), aggregators)
        );

        IOracle impl = deployer.deploy_MagicVaultOracle(
            "Kava_MagicCurveLpOracle_MIM_USDT",
            "MagicCurveLP MIM-USDT Oracle",
            IERC4626(address(vault)),
            aggregator
        );

        if (oracle.oracleImplementation() != impl) {
            vm.broadcast();
            oracle.changeOracleImplementation(impl);
        }
        
        /*
        vm.startBroadcast();
        CauldronDeployLib.deployCauldronV4(
            deployer,
            "Kava_MagicCurveLp_MIM_USDT_Cauldron",
            box,
            toolkit.getAddress(block.chainid, "cauldronV4"),
            IERC20(address(vault)),
            oracle,
            "",
            9800, // 98% ltv
            100, // 1% interests
            0, // 0% opening
            50 // 0.5% liquidation
        );
        vm.stopBroadcast();

        deployer.deploy_DegenBoxERC4626Wrapper("Kava_DegenBoxERC4626Wrapper_MagicCurveLP_MIM_USDT", box, vault);

        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = IERC20(ICurvePool(pool).coins(0));

        deployer.deploy_MagicCurveLpSwapper(
            "Kava_MagicCurveLpSwapper_MIM_USDT",
            box,
            vault,
            IERC20(toolkit.getAddress(block.chainid, "mim")),
            CurvePoolInterfaceType.IFACTORY_POOL,
            pool,
            address(0),
            tokens,
            exchange
        );

        deployer.deploy_MagicCurveLpLevSwapper(
            "Kava_MagicCurveLpLevSwapper_MIM_USDT",
            box,
            vault,
            IERC20(toolkit.getAddress(block.chainid, "mim")),
            CurvePoolInterfaceType.IFACTORY_POOL,
            pool,
            address(0),
            tokens,
            exchange
        );

        _transferOwnershipsAndMintInitial(pool, vault, harvestor, oracle);
        */
    }

    function _transferOwnershipsAndMintInitial(
        address curvePool,
        MagicCurveLp vault,
        MagicCurveLpHarvestor harvestor,
        ProxyOracle oracle
    ) private {
        vm.startBroadcast();
        if (!testing()) {
            if (oracle.owner() != safe) {
                oracle.transferOwnership(safe, true, false);
            }
            if (vault.owner() != safe) {
                vault.transferOwnership(safe, true, false);
            }

            if (vault.totalSupply() == 0) {
                // mint some initial tokens
                ERC20(curvePool).approve(address(vault), ERC20(curvePool).balanceOf(tx.origin));
                vault.deposit(1 ether, safe);
            }

            // deployer needs to be operator of the vault since Gelato doesn't
            // support KAVA yet.
            if (!harvestor.operators(tx.origin)) {
                harvestor.setOperator(tx.origin, true);
            }
        }
        vm.stopBroadcast();
    }
}
