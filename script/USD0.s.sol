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
import {UpperBoundedInverseOracle} from "/oracles/UpperBoundedInverseOracle.sol";

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
            "USD0++Cauldron",
            18,
            0xFC9e30Cf89f8A00dba3D34edf8b65BCDAdeCC1cB,
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
        uint256 ,
        uint256 ,
        uint256 ,
        uint256 
    ) private {
        IOracle(
            deploy(
                string.concat(name, "UpperBoundedInverseOracle"),
                "UpperBoundedInverseOracle.sol:UpperBoundedInverseOracle",
                abi.encode(string.concat(name, "/USD"), chainlinkAggregator, collateralDecimals, 1e8)
            )
        );
    }
}