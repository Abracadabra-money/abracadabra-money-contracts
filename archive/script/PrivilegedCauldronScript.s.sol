// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "utils/CauldronLib.sol";
import "utils/OracleLib.sol";
import "cauldrons/PrivilegedCauldronV4.sol";

contract PrivilegedCauldronScript is BaseScript {
    function run() public {
        IBentoBoxV1 degenBox = IBentoBoxV1(constants.getAddress("mainnet.degenBox"));
        address safe = constants.getAddress("mainnet.safe.ops");
        address mim = constants.getAddress("mainnet.mim");
        address yvstEthOracle = constants.getAddress("mainnet.oracle.yvCrvStETHOracleV2");

        vm.startBroadcast();

        address masterContract = address(new PrivilegedCauldronV4(degenBox, IERC20(mim)));

        ProxyOracle oracle = ProxyOracle(0xacaB7f05A612690B9e05CA3bfC1FF2E99169a39F);

        // always two decimals after the dot
        CauldronLib.deployCauldronV4(
            degenBox,
            masterContract,
            IERC20(constants.getAddress("mainnet.wbtc")),
            oracle,
            "",
            7500, // 75% ltv
            50, // 0.5% interests
            50, // 0.5% opening
            1250 // 12.5% liquidation
        );

        oracle = OracleLib.deploySimpleProxyOracle(IOracle(yvstEthOracle));

        // always two decimals after the dot
        CauldronLib.deployCauldronV4(
            degenBox,
            masterContract,
            IERC20(constants.getAddress("mainnet.yvsteth")),
            oracle,
            "",
            7500, // 75% ltv
            50, // 0.5% interests
            50, // 0.5% opening
            1250 // 12.5% liquidation
        );

        // Only when deploying live
        if (!testing) {
            oracle.transferOwnership(safe, true, false);
            PrivilegedCauldronV4(masterContract).transferOwnership(safe, true, false);
        }

        vm.stopBroadcast();
    }
}
