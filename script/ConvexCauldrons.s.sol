// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "oracles/ProxyOracle.sol";
import "interfaces/ISwapperV2.sol";
import "interfaces/ILevSwapperV2.sol";
import "interfaces/IConvexWrapperFactory.sol";
import "interfaces/IConvexWrapper.sol";
import "swappers/ConvexWrapperSwapper.sol";
import "swappers/ConvexWrapperLevSwapper.sol";

contract ConvexCauldronsScript is BaseScript {
    function run() public {
        startBroadcast();
        deployTricrypto();
        stopBroadcast();
    }

    // Convex Curve USDT​+WBTC​+ETH pool
    function deployTricrypto() public returns (ProxyOracle oracle, ISwapperV2 swapper, ILevSwapperV2 levSwapper) {
        address safe = constants.getAddress("mainnet.safe.ops");
        IConvexWrapperFactory wrapperFactory = IConvexWrapperFactory(constants.getAddress("mainnet.convex.abraWrapperFactory"));
        IBentoBoxV1 box = IBentoBoxV1(constants.getAddress("mainnet.degenBox"));
        IERC20 mim = IERC20(constants.getAddress("mainnet.mim"));
        address exchange = constants.getAddress("mainnet.aggregators.zeroXExchangeProxy");
        address curvePool = constants.getAddress("mainnet.curve.pool.tricrypto");
        IConvexWrapper wrapper = IConvexWrapper(wrapperFactory.CreateWrapper(38));

        swapper = new ConvexWrapperSwapper(box, wrapper, mim, CurvePoolInterfaceType.ITRICRYPTO_POOL, curvePool, 3, exchange);
        levSwapper = new ConvexWrapperLevSwapper(
            box,
            wrapper,
            mim,
            CurvePoolInterfaceType.ITRICRYPTO_POOL,
            ICurvePool(curvePool),
            3,
            exchange
        );

        if (!testing) {
            oracle.transferOwnership(safe, true, false);
        }
    }
}
