// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "cauldrons/CauldronV4.sol";
import "utils/CauldronDeployLib.sol";
import "oracles/ProxyOracle.sol";
import "interfaces/IWETH.sol";
import "tokens/MagicApe.sol";
import "periphery/DegenBoxERC4626Wrapper.sol";
import "periphery/MagicApeHarvestor.sol";
import "periphery/DegenBoxERC4626Wrapper.sol";
import "oracles/MagicApeOracle.sol";
import "swappers/ERC4626Swapper.sol";
import "swappers/ERC4626LevSwapper.sol";

contract MagicApeCauldronScript is BaseScript {
    function deploy()
        public
        returns (
            ICauldronV4 cauldron,
            MagicApe magicApe,
            ProxyOracle oracle
        )
    {
        if (block.chainid == ChainId.Mainnet) {
            startBroadcast();

            address safe = constants.getAddress("mainnet.safe.ops");
            address degenBox = constants.getAddress("mainnet.degenBox");
            address masterContract = constants.getAddress("mainnet.cauldronV4");
            address ape = constants.getAddress("mainnet.ape");
            address mim = constants.getAddress("mainnet.mim");
            address apeUsd = constants.getAddress("mainnet.chainlink.ape");
            address staking = constants.getAddress("mainnet.ape.staking");
            address swapper = constants.getAddress("mainnet.aggregators.zeroXExchangeProxy");
            address gelatoProxy = constants.getAddress("mainnet.safe.devOps.gelatoProxy");
            address devOps = constants.getAddress("safe.devOps");

            magicApe = new MagicApe(ERC20(ape), "magicAPE", "mAPE", IApeCoinStaking(staking));
            MagicApeOracle oracleImpl = new MagicApeOracle(IERC4626(magicApe), IAggregator(apeUsd));

            oracle = new ProxyOracle();
            oracle.changeOracleImplementation(IOracle(oracleImpl));
            cauldron = CauldronDeployLib.deployCauldronV4(
                IBentoBoxV1(degenBox),
                masterContract,
                magicApe,
                oracle,
                "",
                7000, // 70% ltv
                1800, // 18% interests
                0, // 0% opening
                750 // 7.5% liquidation
            );

            new ERC4626Swapper(IBentoBoxV1(degenBox), IERC4626(address(magicApe)), IERC20(mim), swapper);
            new ERC4626LevSwapper(IBentoBoxV1(degenBox), IERC4626(address(magicApe)), IERC20(mim), swapper);

            magicApe.setFeeParameters(safe, 100); // 1% fee

            new DegenBoxERC4626Wrapper(IBentoBoxV1(degenBox), magicApe);
            MagicApeHarvestor harvestor = new MagicApeHarvestor(IMagicApe(address(magicApe)));

            // Only when deploying live
            if (!testing) {
                oracle.transferOwnership(safe, true, false);

                harvestor.setOperator(gelatoProxy, true);
                harvestor.setOperator(devOps, true);

                magicApe.transferOwnership(safe, true, false);

                // mint some initial magicApe
                ERC20(ape).approve(address(magicApe), ERC20(ape).balanceOf(tx.origin));
                magicApe.deposit(1 ether, address(0));
                magicApe.deposit(1 ether, safe);
            }

            stopBroadcast();
        } else {
            revert("chain not supported");
        }
    }
}
