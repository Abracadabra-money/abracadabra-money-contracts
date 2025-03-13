// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {IERC20} from "@BoringSolidity/interfaces/IERC20.sol";
import {Owned} from "@solmate/auth/Owned.sol";
import {LibClone} from "@solady/utils/LibClone.sol";
import {MagicInfraredVault} from "/tokens/MagicInfraredVault.sol";
import {CauldronDeployLib} from "utils/CauldronDeployLib.sol";
import {IAggregator} from "/interfaces/IAggregator.sol";
import {IBentoBoxV1} from "/interfaces/IBentoBoxV1.sol";
import {ProxyOracle} from "/oracles/ProxyOracle.sol";
import {IOracle} from "/interfaces/IOracle.sol";
import {ISwapperV2} from "/interfaces/ISwapperV2.sol";
import {ILevSwapperV2} from "/interfaces/ILevSwapperV2.sol";
import {InverseOracle} from "/oracles/InverseOracle.sol";
import {IInfraredStaking} from "/interfaces/IInfraredStaking.sol";
import {ICauldronV4} from "/interfaces/ICauldronV4.sol";
import {MagicInfraredVault} from "/tokens/MagicInfraredVault.sol";
import {MagicBexVaultHarvester} from "/harvesters/MagicBexVaultHarvester.sol";
import {FixedPriceOracle} from "/oracles/FixedPriceOracle.sol";

struct MagicBexDeployment {
    MagicInfraredVault vault;
    ICauldronV4 cauldron;
    ILevSwapperV2 levSwapper;
    ISwapperV2 swapper;
    MagicBexVaultHarvester harvester;
}

contract MagicBexScript is BaseScript {
    bytes32 constant WETH_BERA_VAULT_SALT = keccak256("MagicBexWethBeraVault_1741789781");
    bytes32 constant WBTC_BERA_VAULT_SALT = keccak256("MagicBexWberaBeraVault_1741789781");

    bytes32 constant WETH_BERA_POOL_ID = bytes32(0xdd70a5ef7d8cfe5c5134b5f9874b09fb5ce812b4000200000000000000000003);
    bytes32 constant WBTC_BERA_POOL_ID = bytes32(0x38fdd999fe8783037db1bbfe465759e312f2d809000200000000000000000004);

    struct CauldronParameters {
        uint256 ltv;
        uint256 interests;
        uint256 openingFee;
        uint256 liquidationFee;
    }

    address mim;
    address box;
    address safe;
    address yieldSafe;
    address masterContract;
    address aggregator;

    function deploy() public returns (MagicBexDeployment memory wethBera, MagicBexDeployment memory wbtcBera) {
        safe = toolkit.getAddress("safe.ops");
        yieldSafe = toolkit.getAddress("safe.yields");
        mim = toolkit.getAddress("mim");

        {
            (MagicInfraredVault vault, ICauldronV4 cauldron, ILevSwapperV2 levSwapper, ISwapperV2 swapper, MagicBexVaultHarvester harvester) = _deployVault(
                "WethBera",
                CauldronParameters({
                    ltv: 9000, // 90% LTV
                    interests: 800, // 8% Interests
                    openingFee: 50, // 0.5% Opening Fee
                    liquidationFee: 750 // 7.5% Liquidation Fee
                }),
                WETH_BERA_POOL_ID,
                toolkit.getAddress("bex.wethbera"),
                IInfraredStaking(toolkit.getAddress("infrared.wethbera")),
                WETH_BERA_VAULT_SALT
            );

            wethBera.vault = vault;
            wethBera.cauldron = cauldron;
            wethBera.levSwapper = levSwapper;
            wethBera.swapper = swapper;
            wethBera.harvester = harvester;
        }

        {
            (MagicInfraredVault vault, ICauldronV4 cauldron, ILevSwapperV2 levSwapper, ISwapperV2 swapper, MagicBexVaultHarvester harvester) = _deployVault(
                "WbtcBera",
                CauldronParameters({
                    ltv: 9000, // 90% LTV
                    interests: 800, // 8% Interests
                    openingFee: 50, // 0.5% Opening Fee
                    liquidationFee: 750 // 7.5% Liquidation Fee
                }),
                WBTC_BERA_POOL_ID,
                toolkit.getAddress("bex.wbtcbera"),
                IInfraredStaking(toolkit.getAddress("infrared.wbtcbera")),
                WBTC_BERA_VAULT_SALT
            );

            wbtcBera.vault = vault;
            wbtcBera.cauldron = cauldron;
            wbtcBera.levSwapper = levSwapper;
            wbtcBera.swapper = swapper;
            wbtcBera.harvester = harvester;
        }
    }

    function _deployVault(
        string memory name,
        CauldronParameters memory parameters,
        bytes32 poolId,
        address asset,
        IInfraredStaking staking,
        bytes32 salt
    ) public returns (MagicInfraredVault vault, ICauldronV4 cauldron, ILevSwapperV2 levSwapper, ISwapperV2 swapper, MagicBexVaultHarvester harvester) {
        vm.startBroadcast();

        vault = MagicInfraredVault(
            deployUpgradeableUsingCreate3(
                string.concat("MagicBexVault_", name),
                salt,
                "MagicInfraredVault.sol:MagicInfraredVault",
                abi.encode(asset),
                abi.encodeCall(MagicInfraredVault.initialize, (tx.origin))
            )
        );

        if (vault.staking() != staking) {
            vault.setStaking(IInfraredStaking(staking));
        }

        (cauldron, levSwapper, swapper) = _deployCauldron(string.concat("MagicBex_", name), address(vault), parameters, poolId);

        harvester = MagicBexVaultHarvester(
            deploy(
                string.concat("MagicBexVaultHarvester_", name),
                "MagicBexVaultHarvester.sol:MagicBexVaultHarvester",
                abi.encode(vault, poolId, tx.origin)
            )
        );

        harvester.grantRoles(toolkit.getAddress("safe.devOps.gelatoProxy"), harvester.ROLE_OPERATOR()); // gelato
        harvester.setExchangeRouter(toolkit.getAddress("oogabooga.router"));
        harvester.setFeeParameters(yieldSafe, 100); // 1% fee on rewards

        vault.setOperator(address(harvester), true);

        if (!testing()) {
            if (vault.owner() != safe) {
                vault.transferOwnership(safe);
            }
            if (harvester.owner() != safe) {
                harvester.transferOwnership(safe);
            }
        }

        vm.stopBroadcast();
    }

    function _deployCauldron(
        string memory name,
        address collateral,
        CauldronParameters memory parameters,
        bytes32 poolId
    ) private returns (ICauldronV4 cauldron, ILevSwapperV2 levSwapper, ISwapperV2 swapper) {
        box = toolkit.getAddress("degenBox");
        masterContract = toolkit.getAddress("cauldronV4");
        ProxyOracle oracle = ProxyOracle(deploy(string.concat(name, "_ProxyOracle"), "ProxyOracle.sol:ProxyOracle"));

        // Temporary aggregator during cauldron deployment to avoid reverting on init because the price feed is not up-to-date yet.
        oracle.changeOracleImplementation(new FixedPriceOracle("", 1e18, 18));

        cauldron = CauldronDeployLib.deployCauldronV4(
            string.concat("Cauldron_", name),
            IBentoBoxV1(box),
            masterContract,
            IERC20(collateral),
            IOracle(address(oracle)),
            "",
            parameters.ltv,
            parameters.interests,
            parameters.openingFee,
            parameters.liquidationFee
        );

        // TODO: Oracle
        //// Now we can change the oracle implementation to the real one
        //address kodiakMimHoneyAggregator = deploy(
        //    "KodiakMimHoneyAggregator",
        //    "KodiakIslandAggregator.sol:KodiakIslandAggregator",
        //    abi.encode(
        //        toolkit.getAddress("kodiak.mimhoney"),
        //        new FixedPriceAggregator(1e8, 8), // MIM always = 1 USD
        //        toolkit.getAddress("pyth.abracadabra.agg.honey")
        //    )
        //);
        //IOracle implOracle = IOracle(
        //    deploy(
        //        string.concat(name, "_ERC4626Oracle"),
        //        "ERC4626Oracle.sol:ERC4626Oracle",
        //        abi.encode(string.concat(name, "/USD"), collateral, kodiakMimHoneyAggregator)
        //    )
        //);
        //oracle.changeOracleImplementation(implOracle);

        swapper = ISwapperV2(
            deploy(
                string.concat(name, "_MIM_VaultSwapper"),
                "MagicBexVaultSwapper.sol:MagicBexVaultSwapper",
                abi.encode(box, collateral, mim, poolId)
            )
        );
        levSwapper = ILevSwapperV2(
            deploy(
                string.concat(name, "_MIM_LevVaultSwapper"),
                "MagicBexVaultLevSwapper.sol:MagicBexVaultLevSwapper",
                abi.encode(box, collateral, mim, poolId)
            )
        );

        deploy(
            string.concat(name, "_DegenBoxERC4626Wrapper"),
            "DegenBoxERC4626Wrapper.sol:DegenBoxERC4626Wrapper",
            abi.encode(box, collateral)
        );

        if (!testing()) {
            if (Owned(address(oracle)).owner() != safe) {
                Owned(address(oracle)).transferOwnership(safe);
            }
        }
    }
}
