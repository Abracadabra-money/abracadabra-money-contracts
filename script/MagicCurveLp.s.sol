// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import "utils/CauldronDeployLib.sol";
import "oracles/ProxyOracle.sol";
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

contract MagicCurveLpScript is BaseScript {
    using DeployerFunctions for Deployer;

    address safe;
    address pool;

    function deploy() public returns (MagicCurveLp vault, MagicCurveLpHarvestor harvestor) {
        if (block.chainid == ChainId.Kava) {
            revert("not ready");
            return _deployKavaMagicMimUsdt();
        } else {
            revert("Unsupported chain");
        }
    }

    function _deployKavaMagicMimUsdt() private returns (MagicCurveLp vault, MagicCurveLpHarvestor harvestor) {
        pool = toolkit.getAddress(block.chainid, "curve.mimusdt.pool");
        safe = toolkit.getAddress(block.chainid, "safe.ops");

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
            "Kava_MagicLevelHarvestor_MIM_USDT_Impl_V1",
            IERC20(toolkit.getAddress(block.chainid, "wKava")),
            2, // MIM/USDT pool is 2 coins length
            1, // Provide liquidity using USDT (index: 1)
            vault
        );

        if (IERC20(pool).allowance(address(harvestor), address(vault)) != type(uint256).max) {
            harvestor.setVaultAssetAllowance(type(uint256).max);
        }

        if (!vault.operators(address(harvestor))) {
            vault.setOperator(address(harvestor), true);
        }

        ProxyOracle oracle = ProxyOracle(deployer.deploy_ProxyOracle("Kava_MagicCurveLpProxyOracle_MIM_USDT"));

        // TODO: Use the vault version here.
        //IOracle impl = IOracle(
        //    new CurveMeta3PoolOracle(
        //        "MIM3CRV",
        //        ICurvePool(toolkit.getAddress("mainnet.curve.mim3pool.pool")),
        //        IAggregator(address(0)), // We can leave out MIM here as it always has a 1 USD (1 MIM) value.
        //        IAggregator(toolkit.getAddress("mainnet.chainlink.dai")),
        //        IAggregator(toolkit.getAddress("mainnet.chainlink.usdc")),
        //        IAggregator(toolkit.getAddress("mainnet.chainlink.usdt"))
        //    )
        //);
        //MagicCurveLpOracle oracle = MagicCurveLpOracle(deployer.deploy_MagicCurveLpOracle("Kava_MagicCurveLpOracle_MIM_USDT_Impl_V1"));
        //if (oracle.implementation() != impl) {
        //  oracle.changeOracleImplementation(IOracle(new MagicLevelOracle(vault, ILevelFinanceLiquidityPool(liquidityPool))));
        //}

        _deployKavaMagicMimUsdtCauldron(vault, oracle, toolkit.getAddress(block.chainid, "aggregators.openocean"));
        _configureVaultStack(pool, vault, harvestor, oracle);
    }

    function _deployKavaMagicMimUsdtCauldron(
        IERC4626 vault,
        ProxyOracle oracle,
        address exchange /* openocean */
    ) private returns (ISwapperV2 swapper, ILevSwapperV2 levSwapper, ICauldronV4 cauldron) {
        IBentoBoxV1 box = IBentoBoxV1(toolkit.getAddress(block.chainid, "degenBox"));
        (swapper, levSwapper) = _deployKavaMimUsdtPoolSwappers(box, vault, exchange);

        vm.startBroadcast();
        cauldron = CauldronDeployLib.deployCauldronV4(
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
    }

    function _deployKavaMimUsdtPoolSwappers(
        IBentoBoxV1 box,
        IERC4626 vault,
        address exchange
    ) private returns (ISwapperV2 swapper, ILevSwapperV2 levSwapper) {
        address curvePool = toolkit.getAddress(block.chainid, "curve.mimusdt.pool");

        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = IERC20(ICurvePool(curvePool).coins(0));
        tokens[1] = IERC20(ICurvePool(curvePool).coins(1));

        swapper = deployer.deploy_MagicCurveLpSwapper(
            "Kava_MagicCurveLpSwapper_MIM_USDT",
            box,
            vault,
            IERC20(toolkit.getAddress(block.chainid, "mim")),
            CurvePoolInterfaceType.IFACTORY_POOL,
            curvePool,
            address(0),
            tokens,
            exchange
        );

        levSwapper = deployer.deploy_MagicCurveLpLevSwapper(
            "Kava_MagicCurveLpLevSwapper_MIM_USDT",
            box,
            vault,
            IERC20(toolkit.getAddress(block.chainid, "mim")),
            CurvePoolInterfaceType.IFACTORY_POOL,
            curvePool,
            address(0),
            tokens,
            exchange
        );
    }

    function _configureVaultStack(address curvePool, MagicCurveLp vault, MagicCurveLpHarvestor harvestor, ProxyOracle oracle) private {
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
