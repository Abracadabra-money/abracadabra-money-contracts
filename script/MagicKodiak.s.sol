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
import {ERC20Oracle} from "/oracles/ERC20Oracle.sol";
import {InverseOracle} from "/oracles/InverseOracle.sol";

contract MagicKodiakScript is BaseScript {
    bytes32 constant VAULT_SALT = keccak256("MagicKodiakVault_IslandMimHoney_1723575016");

    address mim;
    address box;
    address collateral;
    address safe;
    address masterContract;
    address zeroXExchangeProxy;

    function deploy() public returns (MagicKodiakVault instance) {
        vm.startBroadcast();

        address magicKodiak = deploy(
            "MagicKodiakVault_IslandMimHoney_Impl",
            "MagicKodiakVault.sol:MagicKodiakVault",
            abi.encode(toolkit.getAddress("kodiak.islands.mimhoney"))
        );

        instance = MagicKodiakVault(
            deployUsingCreate3("MagicKodiakVault_IslandMimHoney", VAULT_SALT, LibClone.initCodeERC1967(magicKodiak))
        );

        if (instance.version() < 1) {
            instance.initialize(tx.origin, toolkit.getAddress("kodiak.islands.mimhoney.staking"));
        }

        if (instance.owner() != tx.origin) {
            revert("owner should be the deployer");
        }

        if (!instance.operators(tx.origin)) {
            instance.setOperator(tx.origin, true);
        }

        address fixedPriceAggregator = deploy("FixedPriceAggregator", "FixedPriceAggregator.sol:FixedPriceAggregator", abi.encode(1e8, 8));
        deploy(
            "MimHoneyIslandAggregator",
            "KodiakIslandAggregator.sol:KodiakIslandAggregator",
            abi.encode(toolkit.getAddress("kodiak.islands.mimhoney"), fixedPriceAggregator, fixedPriceAggregator)
        );

        _deployCauldron(
            "MagicKodiakCauldron",
            18,
            0xad2f284Db532A57d6940F3A46D875549DCEB030d, // magicKodiak mimHoney / USD
            9000, // 90% LTV
            800, // 8% Interests
            50, // 0.5% Opening Fee
            750 // 7.5% Liquidation Fee
        );

        vm.stopBroadcast();
    }

    function _deployCauldron(
        string memory name,
        uint8 /*collateralDecimals*/,
        address chainlinkAggregator,
        uint256 ltv,
        uint256 interests,
        uint256 openingFee,
        uint256 liquidationFee
    ) private {
        //address mim = toolkit.getAddress("mim");
        box = toolkit.getAddress("degenBox");
        collateral = toolkit.getAddress("magicKodiak.mimhoney");
        //address safe = toolkit.getAddress("safe.ops");
        safe = tx.origin; // testnet only
        masterContract = toolkit.getAddress("cauldronV4");
        //address zeroXExchangeProxy = toolkit.getAddress("aggregators.zeroXExchangeProxy");

        ProxyOracle oracle = ProxyOracle(deploy(string.concat(name, "_ProxyOracle"), "ProxyOracle.sol:ProxyOracle"));
        IOracle impl = IOracle(
            deploy(
                string.concat(name, "_ERC4626Oracle"),
                "ERC4626Oracle.sol:ERC4626Oracle",
                abi.encode(string.concat(name, "/USD"), collateral, chainlinkAggregator)
            )
        );

        if (oracle.oracleImplementation() != impl) {
            oracle.changeOracleImplementation(impl);
        }

        CauldronDeployLib.deployCauldronV4(
            string.concat("Cauldron_", name),
            IBentoBoxV1(box),
            masterContract,
            IERC20(collateral),
            IOracle(address(oracle)),
            "",
            ltv,
            interests,
            openingFee,
            liquidationFee
        );

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
