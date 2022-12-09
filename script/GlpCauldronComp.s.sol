// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "utils/BaseScript.sol";
import "cauldrons/CauldronV4.sol";
import "utils/CauldronLib.sol";
import "oracles/ProxyOracle.sol";
import "periphery/CauldronOwner.sol";
import "interfaces/IGmxRewardRouterV2.sol";
import "tokens/GmxGlpVault.sol";
import "periphery/GmxGlpRewardHandler.sol";
import "periphery/DegenBoxERC20VaultWrapper.sol";
import "periphery/GlpVaultHarvestor.sol";
import "oracles/GLPVaultOracle.sol";

contract GlpCauldronCompScript is BaseScript {
    function run()
        public
        returns (
            ICauldronV4 cauldron,
            GmxGlpVault vault,
            GlpVaultHarvestor harvestor,
            ProxyOracle oracle
        )
    {
        /*
            GmxGlpRewardHandler (Proxy user in GlpVault)
             TODO
             feeCollector: ops
             feePercent: 0
             swapper: GmxGlpVaultSwapper
             rewardTokenEnabled: [weth, gmx]
             swappingTokenOutEnabled: [mim]
             allowedSwappingRecipient: GlpVaultHarvester(for minting glp and transfer into the vault)

            GLP Compounding Cauldron
             TODO
             parameters: 75% ltv 0% interests 0% opening 7.5% liquidation
             blacklisted callee: [degenBox, cauldron, DegenBoxOwner]

            GlpVaultHarvestor (Used For Gelato Offchain Resolver)
             TODO

            DegenBoxERC20VaultWrappr
             TODO
             wrapper: Abra GlpVault

            Abra GmxGlpVault
                TODO
                rewardHandler: GmxGlpRewardHandler
                strategyExecutor: [GlpWrapperHarvestor]
                staked GLP: 0x5402B5F40310bDED796c7D0F3FF6683f5C0cFfdf
                owner: ops

        */
        if (block.chainid == ChainId.Arbitrum) {
            address safe = constants.getAddress("arbitrum.safe.ops");
            address sGlp = constants.getAddress("arbitrum.gmx.sGLP");
            address degenBox = constants.getAddress("arbitrum.degenBox");
            address masterContract = constants.getAddress("arbitrum.cauldronV4");
            address mim = constants.getAddress("arbitrum.mim");
            address weth = constants.getAddress("arbitrum.weth");
            address glpManager = constants.getAddress("arbitrum.gmx.glpManager");
            address rewardRouterV2 = constants.getAddress("arbitrum.gmx.rewardRouterV2");
            address gmx = constants.getAddress("arbitrum.gmx.gmx");

            vm.startBroadcast();
            vault = new GmxGlpVault(IERC20(sGlp), "AbracadabraStakedGlpVault", "abra-GlpVault");
            GLPVaultOracle oracleImpl = new GLPVaultOracle(IGmxGlpManager(glpManager), IERC20(constants.getAddress("arbitrum.gmx.glp")), IERC20Vault(vault));
            oracle = new ProxyOracle();

            oracle.changeOracleImplementation(IOracle(oracleImpl));
            cauldron = CauldronLib.deployCauldronV4(
                IBentoBoxV1(degenBox),
                masterContract,
                vault,
                oracle,
                "",
                7500, // 75% ltv
                0, // 0% interests
                0, // 0% opening
                750 // 7.5% liquidation
            );

            // Periphery contract used to atomically wrap and deposit to degenbox
            new DegenBoxERC20VaultWrapper(IBentoBoxV1(degenBox), vault);

            // Use to facilitate collecting and swapping rewards to the distributor & distribute
            harvestor = new GlpVaultHarvestor(
                IERC20(weth),
                IERC20(mim),
                IGmxRewardRouterV2(rewardRouterV2),
                GmxGlpRewardHandler(address(vault))
            );

            GmxGlpRewardHandler rewardHandler = new GmxGlpRewardHandler();
            rewardHandler.transferOwnership(address(0), true, true); // owner is only from the sGlp wrapper
            vault.setRewardHandler(address(rewardHandler));
            vault.setStrategyExecutor(address(harvestor), true);

            GmxGlpRewardHandler(address(vault)).setFeeParameters(safe, 0);
            GmxGlpRewardHandler(address(vault)).setSwapper(constants.getAddress("arbitrum.aggregators.zeroXExchangProxy"));
            GmxGlpRewardHandler(address(vault)).setRewardRouter(IGmxRewardRouterV2(rewardRouterV2));
            GmxGlpRewardHandler(address(vault)).setRewardTokenEnabled(IERC20(weth), true);
            GmxGlpRewardHandler(address(vault)).setRewardTokenEnabled(IERC20(gmx), true);
            GmxGlpRewardHandler(address(vault)).setSwappingTokenOutEnabled(IERC20(mim), true);
            GmxGlpRewardHandler(address(vault)).setAllowedSwappingRecipient(address(harvestor), true);

            // Only when deploying live
            if (!testing) {
                vault.transferOwnership(safe, true, false);
                harvestor.transferOwnership(safe, true, false);
                oracle.transferOwnership(safe, true, false);
            }

            vm.stopBroadcast();
        } else {
            revert("chain not supported");
        }
    }
}
