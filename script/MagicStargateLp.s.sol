// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import "utils/CauldronDeployLib.sol";
import "oracles/ProxyOracle.sol";
import "tokens/MagicStargateLp.sol";
import "periphery/MagicStargateLpHarvestor.sol";
import "periphery/MagicStargateLpRewardHandler.sol";
import "tokens/MagicStargateLp.sol";
import "interfaces/ISwapperV2.sol";
import "interfaces/ILevSwapperV2.sol";
import "interfaces/ICauldronV4.sol";
import "interfaces/IBentoBoxV1.sol";
import "interfaces/IERC4626.sol";
import "interfaces/IAggregator.sol";

contract MagicStargateLpScript is BaseScript {
    using DeployerFunctions for Deployer;

    address safe;
    address pool;
    address exchange;
    IBentoBoxV1 box;

    function deploy() public returns (MagicStargateLp vault, MagicStargateLpHarvestor harvestor) {
        if (block.chainid == ChainId.Kava) {
            return _deployKavaUSDT();
        } else {
            revert("Unsupported chain");
        }
    }

    function _deployKavaUSDT() private returns (MagicStargateLp vault, MagicStargateLpHarvestor harvestor) {
        pool = toolkit.getAddress(block.chainid, "curve.mimusdt.pool");
        safe = toolkit.getAddress(block.chainid, "safe.ops");
        box = IBentoBoxV1(toolkit.getAddress(block.chainid, "degenBox"));
        exchange = toolkit.getAddress(block.chainid, "aggregators.openocean");

        ICurveRewardGauge gauge = ICurveRewardGauge(toolkit.getAddress(block.chainid, "curve.mimusdt.gauge"));

        vault = MagicStargateLp(
            deployer.deploy_MagicStargateLp("Kava_MagicStargateLp_MIM_USDT", ERC20(pool), "MagicStargateLp MIM-USDT", "mCurveLP-MIM-USDT")
        );

        MagicStargateLpRewardHandler rewardHandler = deployer.deploy_MagicStargateLpRewardHandler(
            "Kava_MagicLevelRewardHandler_MIM_USDT_Impl_V1"
        );

        if (vault.rewardHandler() != rewardHandler) {
            vm.broadcast();
            vault.setRewardHandler(rewardHandler);
        }

        if (MagicStargateLpRewardHandler(address(vault)).staking() != gauge) {
            vm.broadcast();
            MagicStargateLpRewardHandler(address(vault)).setStaking(gauge);
        }

        harvestor = deployer.deploy_MagicStargateLpHarvestor(
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

        ProxyOracle oracle = ProxyOracle(deployer.deploy_ProxyOracle("Kava_MagicStargateLpProxyOracle_MIM_USDT"));

        // TODO: Uncomment when something like USDT aggregator is available
        /*IAggregator[] memory aggregators = new IAggregator[](1);
        aggregators[0] = IAggregator(toolkit.getAddress(block.chainid, "chainlink.usdt"));

        CurveStablePoolAggregator aggregator = CurveStablePoolAggregator(
            deployer.deploy_CurveStablePoolAggregator("Kava_Curve_MIM_USDT_Aggregator", ICurvePool(pool), aggregators)
        );

        IOracle impl = deployer.deploy_MagicVaultOracle(
            "Kava_MagicStargateLpOracle_MIM_USDT",
            "MagicStargateLp MIM-USDT Oracle",
            IERC4626(address(vault)),
            aggregator
        );

        if (oracle.oracleImplementation() != impl) {
            oracle.changeOracleImplementation(impl);
        }

        vm.startBroadcast();
        CauldronDeployLib.deployCauldronV4(
            deployer,
            "Kava_MagicStargateLp_MIM_USDT_Cauldron",
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

        deployer.deploy_DegenBoxERC4626Wrapper("Kava_DegenBoxERC4626Wrapper_MagicStargateLp_MIM_USDT", box, vault);

        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = IERC20(ICurvePool(pool).coins(0));

        deployer.deploy_MagicStargateLpSwapper(
            "Kava_MagicStargateLpSwapper_MIM_USDT",
            box,
            vault,
            IERC20(toolkit.getAddress(block.chainid, "mim")),
            CurvePoolInterfaceType.IFACTORY_POOL,
            pool,
            address(0),
            tokens,
            exchange
        );

        deployer.deploy_MagicStargateLpLevSwapper(
            "Kava_MagicStargateLpLevSwapper_MIM_USDT",
            box,
            vault,
            IERC20(toolkit.getAddress(block.chainid, "mim")),
            CurvePoolInterfaceType.IFACTORY_POOL,
            pool,
            address(0),
            tokens,
            exchange
        );*/

        _transferOwnershipsAndMintInitial(pool, vault, harvestor, oracle);
    }

    function _transferOwnershipsAndMintInitial(
        address curvePool,
        MagicStargateLp vault,
        MagicStargateLpHarvestor harvestor,
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
