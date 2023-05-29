// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "utils/StargateLib.sol";

contract StargateSwappersScript is BaseScript {
    function deploy() public {
        startBroadcast();

        if (block.chainid == ChainId.Mainnet) {
            uint16 usdtPoolId = 2;
            StargateLib.deployZeroExSwappers(
                IBentoBoxV1(constants.getAddress("mainnet.degenBox")),
                IStargatePool(constants.getAddress("mainnet.stargate.usdtPool")),
                usdtPoolId,
                IStargateRouter(constants.getAddress("mainnet.stargate.router")),
                IERC20(constants.getAddress("mainnet.mim")),
                constants.getAddress("mainnet.aggregators.zeroXExchangeProxy")
            );
        }

        stopBroadcast();
    }
}
