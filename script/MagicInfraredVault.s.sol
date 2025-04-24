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
import {KodiakIslandAggregator} from "/oracles/aggregators/KodiakIslandAggregator.sol";
import {IKodiakVaultV1, IKodiakV1RouterStaking} from "/interfaces/IKodiak.sol";
import {FixedPriceOracle} from "/oracles/FixedPriceOracle.sol";
import {FixedPriceAggregator} from "/oracles/aggregators/FixedPriceAggregator.sol";
import {MagicInfraredVaultHarvester} from "/harvesters/MagicInfraredVaultHarvester.sol";
import {IERC4626} from "/interfaces/IERC4626.sol";

// https://forum.abracadabra.money/t/aip-66-berachain-infrared-vault-cauldrons/4911
// Infrared WBERA-HONEY Vault (Kodiak Island)
// Infrared WBERA-WETH Vault (Kodiak Island)
// Infrared WBERA-WBTC Vault (Kodiak Island)
contract MagicInfraredVaultScript is BaseScript {
    address mim;
    address box;
    address safe;
    address yieldSafe;
    address masterContract;
    address aggregator;

    struct CauldronParameters {
        uint256 ltv;
        uint256 interests;
        uint256 openingFee;
        uint256 liquidationFee;
    }

    function deploy() public returns (MagicInfraredVault[] memory vaults, ICauldronV4[] memory cauldrons) {
        safe = toolkit.getAddress("safe.ops");
        yieldSafe = toolkit.getAddress("safe.yields");
        box = toolkit.getAddress("degenBox");
        masterContract = toolkit.getAddress("cauldronV4");
        address honeyAgg = toolkit.getAddress("pyth.abracadabra.agg.honey");
        address wethAgg = toolkit.getAddress("pyth.abracadabra.agg.weth");
        address wbtcAgg = toolkit.getAddress("pyth.abracadabra.agg.wbtc");
        address beraAgg = toolkit.getAddress("pyth.abracadabra.agg.bera");

        vaults = new MagicInfraredVault[](3);
        cauldrons = new ICauldronV4[](3);

        // WBERA-HONEY
        {
            IInfraredStaking staking = IInfraredStaking(toolkit.getAddress("infrared.wberahoney"));
            address asset = toolkit.getAddress("kodiak.wberahoney");
            (vaults[0], cauldrons[0]) = _deploy("Kodiak_WBERA_HONEY", staking, asset, beraAgg, honeyAgg);
        }

        // WBERA-WETH
        {
            IInfraredStaking staking = IInfraredStaking(toolkit.getAddress("infrared.wethwbera"));
            address asset = toolkit.getAddress("kodiak.wethwbera");
            (vaults[1], cauldrons[1]) = _deploy("Kodiak_WETH_WBERA", staking, asset, wethAgg, beraAgg);
        }

        // WBERA-WBTC
        {
            IInfraredStaking staking = IInfraredStaking(toolkit.getAddress("infrared.wbtcwbera"));
            address asset = toolkit.getAddress("kodiak.wbtcwbera");
            (vaults[2], cauldrons[2]) = _deploy("Kodiak_WBTC_WBERA", staking, asset, wbtcAgg, beraAgg);
        }
    }

    function _deploy(
        string memory name,
        IInfraredStaking staking,
        address asset,
        address kodiakIslandAggregator0,
        address kodiakIslandAggregator1
    ) private returns (MagicInfraredVault vault, ICauldronV4 cauldron) {
        vm.startBroadcast();

        bytes32 salt = keccak256(abi.encodePacked("MagicInfraredVault_17235750", name));
        string memory collateralName = string.concat("MagicInfraredVault_", name);

        vault = MagicInfraredVault(
            deployUpgradeableUsingCreate3(
                collateralName,
                salt,
                "MagicInfraredVault.sol:MagicInfraredVault",
                abi.encode(asset),
                abi.encodeCall(MagicInfraredVault.initialize, (tx.origin))
            )
        );

        if (vault.staking() != staking) {
            vault.setStaking(IInfraredStaking(staking));
        }

        cauldron = _deployCauldron(
            collateralName,
            address(vault),
            CauldronParameters({
                ltv: 7500, // 75% LTV
                interests: 1600, // 16% Interests
                openingFee: 50, // 0.5% Opening Fee
                liquidationFee: 800 // 8% Liquidation Fee
            }),
            asset,
            kodiakIslandAggregator0,
            kodiakIslandAggregator1
        );

        MagicInfraredVaultHarvester harvester = MagicInfraredVaultHarvester(
            deploy(
                string.concat(name, "_Harvester"),
                "MagicInfraredVaultHarvester.sol:MagicInfraredVaultHarvester",
                abi.encode(vault, tx.origin)
            )
        );

        harvester.grantRoles(toolkit.getAddress("safe.devOps.gelatoProxy"), harvester.ROLE_OPERATOR()); // gelato

        harvester.setRouter(IKodiakV1RouterStaking(toolkit.getAddress("kodiak.router")));
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
        string memory collateralName,
        address collateral,
        CauldronParameters memory parameters,
        address kodiakIsland,
        address kodiakIslandAggregator0,
        address kodiakIslandAggregator1
    ) private returns (ICauldronV4 cauldron) {
        ProxyOracle oracle = ProxyOracle(deploy(string.concat(collateralName, "_ProxyOracle"), "ProxyOracle.sol:ProxyOracle"));
        // Temporary aggregator during cauldron deployment to avoid reverting on init because the price feed is not up-to-date yet.
        oracle.changeOracleImplementation(new FixedPriceOracle("", 1e18, 18));

        cauldron = CauldronDeployLib.deployCauldronV4(
            string.concat(collateralName, "_Cauldron"),
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

        // Now we can change the oracle implementation to the real one
        address kodiakAggregator = deploy(
            string.concat(collateralName, "_KodiakIsland_Aggregator"),
            "KodiakIslandAggregator.sol:KodiakIslandAggregator",
            abi.encode(kodiakIsland, kodiakIslandAggregator0, kodiakIslandAggregator1)
        );

        IOracle implOracle = IOracle(
            deploy(
                string.concat(collateralName, "_ERC4626Oracle"),
                "ERC4626Oracle.sol:ERC4626Oracle",
                abi.encode(string.concat(collateralName, "/USD"), collateral, kodiakAggregator)
            )
        );

        oracle.changeOracleImplementation(implOracle);

        // Only on mainnet
        /*deploy(
            string.concat(name, "_MIM_TokenSwapper"),
            "ERC4626Swapper.sol:ERC4626Swapper",
            abi.encode(box, collateral, mim, zeroXExchangeProxy)
        );
        deploy(
            string.concat(name, "_MIM_LevTokenSwapper"),
            "ERC4626LevSwapper.sol:ERC4626LevSwapper",
            abi.encode(box, collateral, mim, zeroXExchangeProxy)
        );*/

        deploy(
            string.concat(collateralName, "_DegenBoxERC4626Wrapper"),
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
