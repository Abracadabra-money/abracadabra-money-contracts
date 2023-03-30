// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "oracles/ProxyOracle.sol";
import "tokens/MagicLevel.sol";
import "periphery/MagicLevelHarvestor.sol";
import "periphery/MagicLevelRewardHandler.sol";
import "tokens/MagicLevel.sol";
import "oracles/MagicLevelOracle.sol";

contract MagicLevelFinanceScript is BaseScript {
    function run()
        public
        returns (
            ProxyOracle magicLVLJuniorOracle,
            ProxyOracle magicLVLMezzanineOracle,
            ProxyOracle magicLVLSeniorOracle,
            MagicLevel magicLVLJunior,
            MagicLevel magicLVLMezzanine,
            MagicLevel magicLVLSenior
        )
    {
        if (block.chainid == ChainId.BSC) {
            startBroadcast();
            address juniorLLP = constants.getAddress("bsc.lvlfinance.juniorLLP");
            address mezzanineLLP = constants.getAddress("bsc.lvlfinance.mezzanineLLP");
            address seniorLLP = constants.getAddress("bsc.lvlfinance.seniorLLP");
            address gelatoProxy = constants.getAddress("bsc.safe.devOps.gelatoProxy");
            (magicLVLSeniorOracle, magicLVLSenior) = _deployVaultStack(seniorLLP, "magicLVLSenior", "mLVS", 0, gelatoProxy);
            (magicLVLMezzanineOracle, magicLVLMezzanine) = _deployVaultStack(mezzanineLLP, "magicLVLMezzanine", "mLVM", 1, gelatoProxy);
            (magicLVLJuniorOracle, magicLVLJunior) = _deployVaultStack(juniorLLP, "magicLVLJunior", "mLVJ", 2, gelatoProxy);

            stopBroadcast();
        } else {
            revert("chain not supported");
        }
    }

    function _deployVaultStack(
        address llp,
        string memory name,
        string memory symbol,
        uint96 pid,
        address gelatoProxy
    ) private returns (ProxyOracle oracle, MagicLevel vault) {
        address safe = constants.getAddress("bsc.safe.ops");
        address staking = constants.getAddress("bsc.lvlfinance.levelMasterV2");
        address zeroXExchange = constants.getAddress("bsc.aggregators.zeroXExchangeProxy");
        address liquidityPool = constants.getAddress("bsc.lvlfinance.liquidityPool");

        vault = new MagicLevel(ERC20(llp), name, symbol);
        oracle = new ProxyOracle();
        oracle.changeOracleImplementation(IOracle(new MagicLevelOracle(IERC4626(llp), ILevelFinanceLiquidityPool(liquidityPool))));

        MagicLevelRewardHandler rewardHandler = new MagicLevelRewardHandler();
        rewardHandler.transferOwnership(address(0), true, true);

        MagicLevelHarvestor harvestor = new MagicLevelHarvestor(
            IERC20(constants.getAddress("bsc.lvlfinance.lvlToken")),
            zeroXExchange,
            vault
        );
        harvestor.setFeeParameters(safe, 100); // 1% fee

        vault.setRewardHandler(rewardHandler);
        MagicLevelRewardHandler(address(vault)).setStakingInfo(ILevelFinanceStaking(staking), pid);

        // Only when deploying live
        if (!testing) {
            harvestor.transferOwnership(safe, true, false);
            harvestor.setOperator(gelatoProxy, true);
            harvestor.setOperator(tx.origin, true);

            oracle.transferOwnership(safe, true, false);
            vault.transferOwnership(safe, true, false);

            // mint some initial tokens
            ERC20(llp).approve(address(vault), ERC20(llp).balanceOf(tx.origin));
            vault.deposit(1 ether, safe);
        }
    }
}
