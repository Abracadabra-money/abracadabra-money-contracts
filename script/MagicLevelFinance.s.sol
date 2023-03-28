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

            address safe = constants.getAddress("bsc.safe.ops");
            address masterContract = constants.getAddress("mainnet.cauldronV4");
            address liquidityPool = constants.getAddress("bsc.lvlfinance.liquidityPool");
            address juniorLLP = constants.getAddress("bsc.lvlfinance.juniorLLP");
            address mezzanineLLP = constants.getAddress("bsc.lvlfinance.mezzanineLLP");
            address seniorLLP = constants.getAddress("bsc.lvlfinance.seniorLLP");
            address staking = constants.getAddress("bsc.lvlfinance.levelMasterV2");

            magicLVLJunior = new MagicLevel(ERC20(juniorLLP), "magicLVLJunior", "mLVJ");
            magicLVLMezzanine = new MagicLevel(ERC20(mezzanineLLP), "magicLVLMezzanine", "mLVM");
            magicLVLSenior = new MagicLevel(ERC20(seniorLLP), "magicLVLSenior", "mLVS");

            magicLVLJuniorOracle = new ProxyOracle();
            magicLVLJuniorOracle.changeOracleImplementation(
                IOracle(new MagicLevelOracle(IERC4626(magicLVLJunior), ILevelFinanceLiquidityPool(liquidityPool)))
            );

            magicLVLMezzanineOracle = new ProxyOracle();
            magicLVLMezzanineOracle.changeOracleImplementation(
                IOracle(new MagicLevelOracle(IERC4626(magicLVLMezzanine), ILevelFinanceLiquidityPool(liquidityPool)))
            );

            magicLVLSeniorOracle = new ProxyOracle();
            magicLVLSeniorOracle.changeOracleImplementation(
                IOracle(new MagicLevelOracle(IERC4626(magicLVLSenior), ILevelFinanceLiquidityPool(liquidityPool)))
            );

            magicLVLJunior.setFeeParameters(safe, 100); // 1% fee
            magicLVLMezzanine.setFeeParameters(safe, 100); // 1% fee
            magicLVLSenior.setFeeParameters(safe, 100); // 1% fee

            MagicLevelRewardHandler rewardHandler = new MagicLevelRewardHandler();
            rewardHandler.transferOwnership(address(0), true, true);

            MagicLevelHarvestor harvestor = new MagicLevelHarvestor(magicLVLJunior, magicLVLMezzanine, magicLVLSenior);

            magicLVLJunior.setRewardHandler(rewardHandler);
            magicLVLMezzanine.setRewardHandler(rewardHandler);
            magicLVLSenior.setRewardHandler(rewardHandler);

            MagicLevelRewardHandler(address(magicLVLSenior)).setStakingInfo(staking, 0);
            MagicLevelRewardHandler(address(magicLVLMezzanine)).setStakingInfo(staking, 1);
            MagicLevelRewardHandler(address(magicLVLSenior)).setStakingInfo(staking, 2);

            // Only when deploying live
            if (!testing) {
                oracle.transferOwnership(safe, true, false);

                harvestor.setOperator(gelatoProxy, true);
                harvestor.setOperator(devOps, true);

                magicApe.transferOwnership(safe, true, false);

                // mint some initial tokens
                ERC20(juniorLLP).approve(address(magicLevel), ERC20(ape).balanceOf(tx.origin));
                magicApe.deposit(1 ether, address(0));
                magicApe.deposit(1 ether, safe);
            }

            stopBroadcast();
        } else {
            revert("chain not supported");
        }
    }
}
