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
import {IERC4626} from "/interfaces/IERC4626.sol";
import {ISwapperV2} from "/interfaces/ISwapperV2.sol";
import {ILevSwapperV2} from "/interfaces/ILevSwapperV2.sol";
import {InverseOracle} from "/oracles/InverseOracle.sol";

contract SdeUSDOracleScript is BaseScript {
    function deploy() public {
        vm.startBroadcast();
        deploy(
            string.concat("SdeUSD_ERC4626_Oracle_v2"),
            "ERC4626Oracle.sol:ERC4626Oracle",
            abi.encode(string.concat("SdeUSD/USD"), toolkit.getAddress("elixir.sdeusd"), toolkit.getAddress("chainlink.deusd"))
        );

        vm.stopBroadcast();
    }
}
