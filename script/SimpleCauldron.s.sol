// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {IAggregator} from "interfaces/IAggregator.sol";
import {IBentoBoxV1} from "interfaces/IBentoBoxV1.sol";
import {ProxyOracle} from "oracles/ProxyOracle.sol";
import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {IOracle} from "interfaces/IOracle.sol";
import {ISwapperV2} from "interfaces/ISwapperV2.sol";
import {ILevSwapperV2} from "interfaces/ILevSwapperV2.sol";
import {CauldronDeployLib} from "utils/CauldronDeployLib.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {ChainlinkOracle} from "oracles/ChainlinkOracle.sol";
import {InverseOracle} from "oracles/InverseOracle.sol";

contract SimpleCauldronScript is BaseScript {
    address mim;
    address box;
    address safe;
    address masterContract;
    address zeroXExchangeProxy;

    function deploy() public {
        mim = toolkit.getAddress(block.chainid, "mim");
        box = toolkit.getAddress(block.chainid, "degenBox");
        safe = toolkit.getAddress(block.chainid, "safe.ops");
        masterContract = toolkit.getAddress(block.chainid, "cauldronV4");
        zeroXExchangeProxy = toolkit.getAddress(block.chainid, "aggregators.zeroXExchangeProxy");

        // SAIP #43
        // https://snapshot.org/#/abracadabrabymerlinthemagician.eth/proposal/0x34e25dcfcfa50e574cc322c430efdb21c7a502cd8b97e2f27fd92f9448375522
        if (block.chainid == ChainId.Arbitrum) {
            vm.startBroadcast();
            _deploy(
                "WBTC",
                toolkit.getAddress(block.chainid, "wbtc"),
                8,
                toolkit.getAddress(block.chainid, "chainlink.btc"),
                8000, // 80% ltv
                600, // 6.0% interests
                25, // 0.25% opening
                600 // 6% liquidation
            );

            _deploy(
                "WETH",
                toolkit.getAddress(block.chainid, "weth"),
                18,
                toolkit.getAddress(block.chainid, "chainlink.eth"),
                8000, // 80% ltv
                600, // 6.0% interests
                25, // 0.25% opening
                600 // 6% liquidation
            );
        }

        vm.stopBroadcast();
    }

    function _deploy(
        string memory name,
        address collateral,
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
                string.concat(name, "_ChainlinkOracle"),
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
            abi.encode(box, collateral, mim, zeroXExchangeProxy)
        );
        deploy(
            string.concat(name, "_MIM_LevTokenSwapper"),
            "TokenLevSwapper.sol:TokenLevSwapper",
            abi.encode(box, collateral, mim, zeroXExchangeProxy)
        );

        if (!testing()) {
            if (Owned(address(oracle)).owner() != safe) {
                Owned(address(oracle)).transferOwnership(safe);
            }
        }
    }
}
