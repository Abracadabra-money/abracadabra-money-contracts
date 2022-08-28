// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "utils/BaseScript.sol";
import "oracles/ProxyOracle.sol";
import "oracles/InverseOracle.sol";
import "swappers/ZeroXTokenSwapper.sol";
import "swappers/ZeroXTokenLevSwapper.sol";

contract LiquityScript is BaseScript {
    function run()
        public
        returns (
            ProxyOracle oracle,
            ISwapperV2 swapper,
            ILevSwapperV2 levSwapper
        )
    {
        address xMerlin = constants.getAddress("xMerlin");

        vm.startBroadcast();

        // LUSD Oracle
        oracle = ProxyOracle(0x3Cc89EA432c36c8F96731765997722192202459D);

        swapper = new ZeroXTokenSwapper(
            IBentoBoxV1(constants.getAddress("mainnet.degenBox")),
            IERC20(constants.getAddress("mainnet.liquity.lusd")),
            IERC20(constants.getAddress("mainnet.mim")),
            constants.getAddress("mainnet.aggregators.zeroXExchangProxy")
        );

        levSwapper = new ZeroXTokenLevSwapper(
            IBentoBoxV1(constants.getAddress("mainnet.degenBox")),
            IERC20(constants.getAddress("mainnet.liquity.lusd")),
            IERC20(constants.getAddress("mainnet.mim")),
            constants.getAddress("mainnet.aggregators.zeroXExchangProxy")
        );

        if (!testing) {}

        vm.stopBroadcast();
    }
}
