// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "utils/CauldronDeployLib.sol";
import "utils/OracleLib.sol";

contract CrvCauldronScript is BaseScript {
    function run() public {
        IBentoBoxV1 degenBox = IBentoBoxV1(constants.getAddress("mainnet.degenBox"));
        address safe = constants.getAddress("mainnet.safe.ops");
        address chainlinkOracle = constants.getAddress("mainnet.chainlink.crv");
        address masterContract = constants.getAddress("mainnet.cauldronV4");

        vm.startBroadcast();

        ProxyOracle oracle = OracleLib.deploySimpleInvertedOracle("CRV/USD", IAggregator(chainlinkOracle));
    
        CauldronDeployLib.deployCauldronV4(
            degenBox,
            masterContract,
            IERC20(constants.getAddress("mainnet.crv")),
            oracle,
            "",
            7500, // 75% ltv
            1800, // 18% interests
            0, // 0% opening
            1000 // 10% liquidation
        );

        // Only when deploying live
        if (!testing) {
            oracle.transferOwnership(safe, true, false);
        }

        vm.stopBroadcast();
    }
}
