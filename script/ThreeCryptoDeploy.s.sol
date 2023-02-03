// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "utils/CauldronLib.sol";
import "utils/OracleLib.sol";
import "oracles/3CryptoOracle.sol";
import "swappers/ThreeCryptoLevSwapper.sol";
import "swappers/ThreeCryptoSwapper.sol";

contract ThreeCryptoDeployScript is BaseScript {
    function run()
        public
        returns (
            ProxyOracle oracle,
            ThreeCryptoLevSwapper levSwapper,
            ThreeCryptoSwapper swapper,
            ICauldronV4 cauldron
        )
    {
        vm.startBroadcast();


        vm.stopBroadcast();
    }
}
