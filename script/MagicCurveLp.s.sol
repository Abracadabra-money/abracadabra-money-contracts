// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import "oracles/ProxyOracle.sol";
import "tokens/MagicCurveLp.sol";
import "periphery/MagicCurveLpHarvestor.sol";
import "periphery/MagicCurveLpRewardHandler.sol";
import "tokens/MagicCurveLp.sol";
import "interfaces/ICurveRewardGauge.sol";
import "interfaces/IERC4626.sol";

contract MagicCurveLpScript is BaseScript {
    using DeployerFunctions for Deployer;

    function deploy() public returns (MagicCurveLp vault, MagicCurveLpHarvestor harvestor) {
        if (block.chainid == ChainId.Kava) {
            return _deployKavaMimUsdtVault();
        } else {
            revert("Unsupported chain");
        }
    }

    function _deployKavaMimUsdtVault() private returns (MagicCurveLp vault, MagicCurveLpHarvestor harvestor) {
        address pool = toolkit.getAddress(block.chainid, "curve.mimusdt.token");
        ICurveRewardGauge gauge = ICurveRewardGauge(toolkit.getAddress(block.chainid, "curve.mimusdt.gauge"));

        vault = MagicCurveLp(
            deployer.deploy_MagicCurveLp("Kava_MagicCurveLp_MIM_USDT", ERC20(pool), "magicCurveLP MIM-USDT", "mCurveLP-MIM-USDT")
        );

        MagicCurveLpRewardHandler rewardHandler = deployer.deploy_MagicCurveLpRewardHandler(
            "Kava_MagicLevelRewardHandler_MIM_USDT_Impl_V1"
        );

        harvestor = deployer.deploy_MagicCurveLpHarvestor(
            "Kava_MagicLevelHarvestor_MIM_USDT_Impl_V1",
            IERC20(toolkit.getAddress(block.chainid, "wKava"))
        );

        ProxyOracle oracle = ProxyOracle(deployer.deploy_ProxyOracle("Kava_MagicCurveLpProxyOracle_MIM_USDT"));
        //MagicCurveLpOracle oracle = MagicCurveLpOracle(deployer.deploy_MagicCurveLpOracle("Kava_MagicCurveLpOracle_MIM_USDT_Impl_V1"));
        //oracle.changeOracleImplementation(IOracle(new MagicLevelOracle(vault, ILevelFinanceLiquidityPool(liquidityPool))));

        _configureVaultStack(pool, vault, gauge, rewardHandler, harvestor, oracle);
    }

    function _configureVaultStack(
        address curvePool,
        MagicCurveLp vault,
        ICurveRewardGauge gauge,
        MagicCurveLpRewardHandler rewardHandler,
        MagicCurveLpHarvestor harvestor,
        ProxyOracle oracle
    ) private {
        address safe = toolkit.getAddress(block.chainid, "safe.ops");

        vault.setRewardHandler(rewardHandler);

        MagicCurveLpRewardHandler(address(vault)).setStaking(gauge);
        harvestor.setVaultAssetAllowance(IERC4626(address(vault)), type(uint256).max);
        vault.setOperator(address(harvestor), true);

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
        }
    }
}
