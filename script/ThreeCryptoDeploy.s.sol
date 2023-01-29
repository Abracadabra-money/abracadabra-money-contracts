// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "utils/CauldronLib.sol";
import "utils/OracleLib.sol";
import "oracles/3CryptoOracle.sol";

contract ThreeCryptoDeployScript is BaseScript {
    function run() public {
        IBentoBoxV1 degenBox = IBentoBoxV1(constants.getAddress("mainnet.degenBox"));
        address safe = constants.getAddress("mainnet.safe.ops");
        address masterContract = constants.getAddress("mainnet.cauldronV4");

        vm.startBroadcast();

        ThreeCryptoOracle threecryptooracle = new ThreeCryptoOracle();

        ProxyOracle oracle = OracleLib.deploySimpleProxyOracle(threecryptooracle);
    
        CauldronLib.deployCauldronV4(
            degenBox,
            masterContract,
            IERC20(constants.getAddress("mainnet.crv")),
            oracle,
            "",
            9000, // 90% ltv
            600, // 6% interests
            0, // 0% opening
            400 // 4% liquidation
        );

        // Only when deploying live
        if (!testing) {
            oracle.transferOwnership(safe, true, false);
        }

        vm.stopBroadcast();
    }
}
