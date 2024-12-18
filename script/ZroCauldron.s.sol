// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {IERC20} from "@BoringSolidity/interfaces/IERC20.sol";
import {Owned} from "@solmate/auth/Owned.sol";
import "utils/BaseScript.sol";

import {CauldronDeployLib} from "utils/CauldronDeployLib.sol";
import {IAggregator} from "/interfaces/IAggregator.sol";
import {IBentoBoxV1} from "/interfaces/IBentoBoxV1.sol";
import {ProxyOracle} from "/oracles/ProxyOracle.sol";
import {IOracle} from "/interfaces/IOracle.sol";
import {ISwapperV2} from "/interfaces/ISwapperV2.sol";
import {ILevSwapperV2} from "/interfaces/ILevSwapperV2.sol";
import {InverseOracle} from "/oracles/InverseOracle.sol";

contract ZroCauldronScript is BaseScript {
    address collateral;
    address mim;
    address box;
    address safe;
    address masterContract;

    function deploy() public {
        mim = toolkit.getAddress("mim");
        box = toolkit.getAddress("degenBox");
        collateral = toolkit.getAddress("zro");
        safe = toolkit.getAddress("safe.ops");
        masterContract = toolkit.getAddress("cauldronV4");

        vm.startBroadcast();
        _deploy(
            "ZroCauldron",
            18,
            toolkit.getAddress("chainlink.zro"),
            8000, // 80% LTV
            900, // 9% Interests
            100, // 1% Opening Fee
            600 // 6% Liquidation Fee
        );

        vm.stopBroadcast();
    }

    function _deploy(
        string memory name,
        uint8 collateralDecimals,
        address chainlinkAggregator,
        uint256 ltv,
        uint256 interests,
        uint256 openingFee,
        uint256 liquidationFee
    ) private {
        ProxyOracle oracle = ProxyOracle(deploy(string.concat(name, "_ProxyOracle"), "ProxyOracle.sol:ProxyOracle"));
        IOracle impl = IOracle(
            deploy(
                string.concat(name, "_InverseERC20Oracle"),
                "InverseOracle.sol:InverseOracle",
                abi.encode(string.concat(name, "/USD"), chainlinkAggregator, collateralDecimals)
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

        deploy(
            string.concat(name, "_MIM_TokenSwapper"),
            "TokenSwapper.sol:TokenSwapper",
            abi.encode(box, collateral, mim)
        );
        deploy(
            string.concat(name, "_MIM_LevTokenSwapper"),
            "TokenLevSwapper.sol:TokenLevSwapper",
            abi.encode(box, collateral, mim)
        );
       
        if (!testing()) {
            if (Owned(address(oracle)).owner() != safe) {
                Owned(address(oracle)).transferOwnership(safe);
            }
        }
    }
}