// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "utils/CauldronLib.sol";
import "utils/OracleLib.sol";
import "oracles/3CryptoOracle.sol";
import "swappers/ThreeCryptoLevSwapper.sol";
import "swappers/ThreeCryptoSwapper.sol";

contract ThreeCryptoScript is BaseScript {
    function run()
        public
        returns (
            ProxyOracle oracle,
            ThreeCryptoLevSwapper levSwapper,
            ThreeCryptoSwapper swapper,
            ICauldronV4 cauldron
        )
    {
        IBentoBoxV1 degenBox = IBentoBoxV1(constants.getAddress("mainnet.degenBox"));
        address safe = constants.getAddress("mainnet.safe.ops");
        address masterContract = constants.getAddress("mainnet.cauldronV4");

        vm.startBroadcast();

        ThreeCryptoOracle threecryptooracle = new ThreeCryptoOracle(constants.getAddress("mainnet.y3Crypto"));

        oracle = OracleLib.deploySimpleProxyOracle(threecryptooracle);

        cauldron = CauldronLib.deployCauldronV4(
            degenBox,
            masterContract,
            IERC20(constants.getAddress("mainnet.y3Crypto")),
            oracle,
            "",
            9000, // 90% ltv
            700, // 7% interests
            0, // 0% opening
            400 // 4% liquidation
        );

        levSwapper = new ThreeCryptoLevSwapper(degenBox);
        swapper = new ThreeCryptoSwapper(degenBox);

        // Only when deploying live
        if (!testing) {
            oracle.transferOwnership(safe, true, false);
        }

        vm.stopBroadcast();
    }
}
