// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "utils/BaseScript.sol";
import "swappers/StargateCurveSwapper.sol";
import "periphery/StargateLPMIMPool.sol";

contract StargateCurveSwapperScript is BaseScript {
    function run() public {
        address xMerlin = constants.getAddress("xMerlin");

        vm.startBroadcast();

        StargateLPMIMPool mimPool = new StargateLPMIMPool(
            IERC20(constants.getAddress("mainnet.mim")),
            IAggregator(constants.getAddress("mainnet.chainlink.mim")),
            IStargateRouter(constants.getAddress("mainnet.stargate.router"))
        );

        StargateCurveSwapper usdcSwapper = new StargateCurveSwapper(
            IBentoBoxV1(constants.getAddress("mainnet.degenBox")),
            IStargatePool(constants.getAddress("mainnet.stargate.usdcPool")),
            1,
            IStargateRouter(constants.getAddress("mainnet.stargate.router")),
            ICurvePool(constants.getAddress("mainnet.curve.mim3Crv")),
            2,
            0
        );

        StargateCurveSwapper usdtSwapper = new StargateCurveSwapper(
            IBentoBoxV1(constants.getAddress("mainnet.degenBox")),
            IStargatePool(constants.getAddress("mainnet.stargate.usdtPool")),
            2,
            IStargateRouter(constants.getAddress("mainnet.stargate.router")),
            ICurvePool(constants.getAddress("mainnet.curve.mim3Crv")),
            3,
            0
        );

        if (!testing) {
            usdcSwapper.setMimPool(IStargateLpMimPool(address(mimPool)));
            usdtSwapper.setMimPool(IStargateLpMimPool(address(mimPool)));

            mimPool.setPool(
                IStargatePool(constants.getAddress("mainnet.stargate.usdcPool")),
                1,
                IOracle(0x16495612E7B35bBC8C672cd76De83BcC81774552),
                14
            );
            mimPool.setPool(
                IStargatePool(constants.getAddress("mainnet.stargate.usdtPool")),
                2,
                IOracle(0xaBB326cD92b0e48fa6dfC54d69Cd1750a1007a97),
                14
            );

            mimPool.setAllowedExecutor(xMerlin, true);
            mimPool.setAllowedRedeemer(address(usdcSwapper), true);
            mimPool.setAllowedRedeemer(address(usdtSwapper), true);
            mimPool.transferOwnership(xMerlin, true, false);
            usdcSwapper.transferOwnership(xMerlin, true, false);
            usdtSwapper.transferOwnership(xMerlin, true, false);
        }

        vm.stopBroadcast();
    }
}
