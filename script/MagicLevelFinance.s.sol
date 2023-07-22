// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "oracles/ProxyOracle.sol";
import "tokens/MagicLevel.sol";
import "periphery/MagicLevelHarvestor.sol";
import "periphery/MagicLevelRewardHandler.sol";
import "tokens/MagicLevel.sol";
import "oracles/MagicLevelOracle.sol";
import "lenses/LevelFinanceStakingLens.sol";

contract MagicLevelFinanceScript is BaseScript {
    function deploy()
        public
        returns (
            ProxyOracle magicLVLJuniorOracle,
            ProxyOracle magicLVLMezzanineOracle,
            ProxyOracle magicLVLSeniorOracle,
            MagicLevel magicLVLJunior,
            MagicLevel magicLVLMezzanine,
            MagicLevel magicLVLSenior,
            MagicLevelHarvestor harvestor
        )
    {
        if (block.chainid == ChainId.BSC) {
            vm.startBroadcast();
            address safe = toolkit.getAddress("bsc.safe.ops");
            address juniorLLP = toolkit.getAddress("bsc.lvlfinance.juniorLLP");
            address mezzanineLLP = toolkit.getAddress("bsc.lvlfinance.mezzanineLLP");
            address seniorLLP = toolkit.getAddress("bsc.lvlfinance.seniorLLP");
            address gelatoProxy = toolkit.getAddress("bsc.safe.devOps.gelatoProxy");
            address zeroXExchange = toolkit.getAddress("bsc.aggregators.zeroXExchangeProxy");

            harvestor = new MagicLevelHarvestor(IERC20(toolkit.getAddress("bsc.lvlfinance.lvlToken")));
            harvestor.setFeeParameters(safe, 100); // 1% fee
            harvestor.setLiquidityPoolAllowance(
                toolkit.getAddress("bsc.lvlfinance.liquidityPool"),
                IERC20(toolkit.getAddress("bsc.wbnb")),
                type(uint256).max
            );
            harvestor.setExchangeRouter(zeroXExchange);

            MagicLevelRewardHandler rewardHandler = new MagicLevelRewardHandler();
            rewardHandler.transferOwnership(address(0), true, true);

            (magicLVLSeniorOracle, magicLVLSenior) = _deployVaultStack(seniorLLP, "magicLLP Senior", "mLVS", 0, rewardHandler, harvestor);
            (magicLVLMezzanineOracle, magicLVLMezzanine) = _deployVaultStack(
                mezzanineLLP,
                "magicLLP Mezzanine",
                "mLVM",
                1,
                rewardHandler,
                harvestor
            );
            (magicLVLJuniorOracle, magicLVLJunior) = _deployVaultStack(juniorLLP, "magicLLP Junior", "mLVJ", 2, rewardHandler, harvestor);

            new LevelFinanceStakingLens(ILevelFinanceStaking(toolkit.getAddress("bsc.lvlfinance.levelMasterV2")));

            if (!testing()) {
                harvestor.setOperator(gelatoProxy, true);
                harvestor.setOperator(tx.origin, true);
                harvestor.transferOwnership(safe, true, false);
            }

            vm.stopBroadcast();
        } else {
            revert("chain not supported");
        }
    }

    function _deployVaultStack(
        address llp,
        string memory name,
        string memory symbol,
        uint96 pid,
        MagicLevelRewardHandler rewardHandler,
        MagicLevelHarvestor harvestor
    ) private returns (ProxyOracle oracle, MagicLevel vault) {
        address safe = toolkit.getAddress("bsc.safe.ops");
        address staking = toolkit.getAddress("bsc.lvlfinance.levelMasterV2");
        address liquidityPool = toolkit.getAddress("bsc.lvlfinance.liquidityPool");

        vault = new MagicLevel(ERC20(llp), name, symbol);
        vault.setRewardHandler(rewardHandler);

        oracle = new ProxyOracle();
        oracle.changeOracleImplementation(IOracle(new MagicLevelOracle(vault, ILevelFinanceLiquidityPool(liquidityPool))));
        MagicLevelRewardHandler(address(vault)).setStakingInfo(ILevelFinanceStaking(staking), pid);

        harvestor.setVaultAssetAllowance(IERC4626(address(vault)), type(uint256).max);
        vault.setOperator(address(harvestor), true);
        
        if (!testing()) {
            oracle.transferOwnership(safe, true, false);
            vault.transferOwnership(safe, true, false);

            // mint some initial tokens
            ERC20(llp).approve(address(vault), ERC20(llp).balanceOf(tx.origin));
            vault.deposit(1 ether, safe);
        }
    }
}
