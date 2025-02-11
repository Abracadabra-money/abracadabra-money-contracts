// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {IERC20} from "@BoringSolidity/interfaces/IERC20.sol";
import {Owned} from "@solmate/auth/Owned.sol";
import {LibClone} from "@solady/utils/LibClone.sol";
import {MagicKodiakVault} from "/tokens/MagicKodiakVault.sol";
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
import {MagicKodiakVaultHarvester} from "/harvesters/MagicKodiakVaultHarvester.sol";

contract MagicKodiakMimHoneyScript is BaseScript {
    bytes32 constant VAULT_SALT = keccak256("MagicKodiakMimHoney_1723575017");

    address mim;
    address box;
    address safe;
    address yieldSafe;
    address masterContract;
    address oogaboogaAggregator;
    address kodiakRouter;

    struct CauldronParameters {
        uint256 ltv;
        uint256 interests;
        uint256 openingFee;
        uint256 liquidationFee;
    }

    function deploy() public returns (MagicKodiakVault vault, ICauldronV4 cauldron, ISwapperV2 swapper, ILevSwapperV2 levSwapper) {
        safe = toolkit.getAddress("safe.ops");
        yieldSafe = toolkit.getAddress("safe.yields");
        IInfraredStaking staking = IInfraredStaking(toolkit.getAddress("infrared.mimhoney"));
        address asset = toolkit.getAddress("kodiak.mimhoney");
        oogaboogaAggregator = toolkit.getAddress("oogabooga.router");
        kodiakRouter = toolkit.getAddress("kodiak.router");
        mim = toolkit.getAddress("mim");

        vm.startBroadcast();

        vault = MagicKodiakVault(
            deployUpgradeableUsingCreate3(
                "MagicKodiakMimHoney",
                VAULT_SALT,
                "MagicKodiakVault.sol:MagicKodiakVault",
                abi.encode(asset),
                abi.encodeCall(MagicKodiakVault.initialize, (tx.origin))
            )
        );

        if (vault.staking() != staking) {
            vault.setStaking(IInfraredStaking(staking));
        }

        (cauldron, swapper, levSwapper) = _deployCauldron(
            address(vault),
            CauldronParameters({
                ltv: 9000, // 90% LTV
                interests: 800, // 8% Interests
                openingFee: 50, // 0.5% Opening Fee
                liquidationFee: 750 // 7.5% Liquidation Fee
            })
        );

        MagicKodiakVaultHarvester harvester = MagicKodiakVaultHarvester(
            deploy("MagicKodiakMimHoneyHarvester", "MagicKodiakVaultHarvester.sol:MagicKodiakVaultHarvester", abi.encode(vault, tx.origin))
        );

        harvester.grantRoles(toolkit.getAddress("safe.devOps.gelatoProxy"), harvester.ROLE_OPERATOR()); // gelato

        harvester.setRouter(IKodiakV1RouterStaking(toolkit.getAddress("kodiak.router")));
        harvester.setExchangeRouter(oogaboogaAggregator);
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
        address collateral,
        CauldronParameters memory parameters
    ) private returns (ICauldronV4 cauldron, ISwapperV2 swapper, ILevSwapperV2 levSwapper) {
        box = toolkit.getAddress("degenBox");
        masterContract = toolkit.getAddress("cauldronV4");
        ProxyOracle oracle = ProxyOracle(deploy(string.concat("MagicKodiakMimHoney_ProxyOracle"), "ProxyOracle.sol:ProxyOracle"));

        // Temporary aggregator during cauldron deployment to avoid reverting on init because the price feed is not up-to-date yet.
        oracle.changeOracleImplementation(new FixedPriceOracle("", 1e18, 18));

        cauldron = CauldronDeployLib.deployCauldronV4(
            string.concat("Cauldron_MagicKodiakMimHoney"),
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
        address kodiakMimHoneyAggregator = deploy(
            "KodiakMimHoneyAggregator",
            "KodiakIslandAggregator.sol:KodiakIslandAggregator",
            abi.encode(
                toolkit.getAddress("kodiak.mimhoney"),
                new FixedPriceAggregator(1e8, 8), // MIM always = 1 USD
                toolkit.getAddress("pyth.abracadabra.agg.honey")
            )
        );

        IOracle implOracle = IOracle(
            deploy(
                string.concat("MagicKodiakMimHoney_ERC4626Oracle"),
                "ERC4626Oracle.sol:ERC4626Oracle",
                abi.encode(string.concat("MagicKodiakMimHoney/USD"), collateral, kodiakMimHoneyAggregator)
            )
        );

        oracle.changeOracleImplementation(implOracle);

        swapper = ISwapperV2(
            deploy(
                string.concat("MagicKodiakMimHoney_Swapper"),
                "MagicKodiakIslandSwapper.sol:MagicKodiakIslandSwapper",
                abi.encode(box, collateral, mim, kodiakRouter)
            )
        );
        levSwapper = ILevSwapperV2(
            deploy(
                string.concat("MagicKodiakMimHoney_LevSwapper"),
                "MagicKodiakIslandLevSwapper.sol:MagicKodiakIslandLevSwapper",
                abi.encode(box, collateral, mim, kodiakRouter)
            )
        );
        deploy(
            string.concat("MagicKodiakMimHoney_DegenBoxERC4626Wrapper"),
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
