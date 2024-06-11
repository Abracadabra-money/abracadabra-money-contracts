// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {CauldronDeployLib} from "utils/CauldronDeployLib.sol";
import {IBentoBoxV1} from "interfaces/IBentoBoxV1.sol";
import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {IOracle} from "interfaces/IOracle.sol";

contract BartioCauldronScript is BaseScript {
    function deploy() public {
        vm.startBroadcast();
        IOracle oracle = IOracle(deploy("BexHoneyMimOracle", "FixedPriceOracle.sol:FixedPriceOracle", abi.encode("MIM/HONEY", 1e18, 18)));

        address(
            CauldronDeployLib.deployCauldronV4(
                "MIMHONEY_Cauldron",
                IBentoBoxV1(toolkit.getAddress(ChainId.Bera, "degenBox")),
                toolkit.getAddress(ChainId.Bera, "cauldronV4"),
                IERC20(toolkit.getAddress(ChainId.Bera, "bex.pools.mimhoney")),
                oracle,
                "",
                9000, // 90% ltv
                500, // 5% interests
                100, // 1% opening
                600 // 6% liquidation
            )
        );
        vm.stopBroadcast();
    }
}
