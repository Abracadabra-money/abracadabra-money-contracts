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
        oracle.changeOracleImplementation(IOracle(new MagicLevelOracle(vault, ILevelFinanceLiquidityPool(liquidityPool))));

        MagicLevelRewardHandler rewardHandler = new MagicLevelRewardHandler();
        rewardHandler.transferOwnership(address(0), true, true);

        MagicLevelHarvestor harvestor = new MagicLevelHarvestor(
            IERC20(constants.getAddress("bsc.lvlfinance.lvlToken")),
            zeroXExchange,
            vault
        );
        harvestor.setFeeParameters(safe, 100); // 1% fee
        harvestor.setStakingAllowance(ILevelFinanceStaking(staking), IERC20(0x55d398326f99059fF775485246999027B3197955), type(uint256).max); // USDT
        harvestor.setStakingAllowance(ILevelFinanceStaking(staking), IERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56), type(uint256).max); // BUSD
        harvestor.setStakingAllowance(ILevelFinanceStaking(staking), IERC20(0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c), type(uint256).max); // BTC
        harvestor.setStakingAllowance(ILevelFinanceStaking(staking), IERC20(0x2170Ed0880ac9A755fd29B2688956BD959F933F8), type(uint256).max); // ETH
        harvestor.setStakingAllowance(ILevelFinanceStaking(staking), IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c), type(uint256).max); // WBNB
        harvestor.setStakingAllowance(ILevelFinanceStaking(staking), IERC20(0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82), type(uint256).max); // CAKE

        vault.setRewardHandler(rewardHandler);
        MagicLevelRewardHandler(address(vault)).setStakingInfo(ILevelFinanceStaking(staking), pid);

        // Only when deploying live
        if (!testing) {
            harvestor.setOperator(gelatoProxy, true);
            harvestor.setOperator(tx.origin, true);
            harvestor.transferOwnership(safe, true, false);

            oracle.transferOwnership(safe, true, false);
            vault.transferOwnership(safe, true, false);

            // mint some initial tokens
            ERC20(llp).approve(address(vault), ERC20(llp).balanceOf(tx.origin));
            vault.deposit(1 ether, safe);
        }
    }
}
