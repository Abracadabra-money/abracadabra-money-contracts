// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "oracles/ProxyOracle.sol";
//import "oracles/ConvexWrapperOracle.sol";
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
        address curvePool = constants.getAddress("mainnet.curve.tricrypto.pool");
        IConvexWrapper wrapper = IConvexWrapper(wrapperFactory.CreateWrapper(38));

        IERC20[] memory tokens = new IERC20[](3);
        tokens[0] = IERC20(ICurvePool(curvePool).coins(0));
        tokens[1] = IERC20(ICurvePool(curvePool).coins(1));
        tokens[2] = IERC20(ICurvePool(curvePool).coins(2));

        swapper = new ConvexWrapperSwapper(box, wrapper, mim, CurvePoolInterfaceType.ITRICRYPTO_POOL, curvePool, address(0), tokens, exchange);
        levSwapper = new ConvexWrapperLevSwapper(
            box,
            wrapper,
            mim,
            CurvePoolInterfaceType.ITRICRYPTO_POOL,
            curvePool,
            address(0),
            tokens,
            exchange
        );

        oracle = new ProxyOracle();
        //oracle.changeOracleImplementation(IOracle(new ConvexWrapperOracle()));

        if (!testing) {
            oracle.transferOwnership(safe, true, false);
        }
    }

    // Convex Curve USDT​+WBTC​+ETH pool
    function deployMimPool() public returns (ProxyOracle oracle, ISwapperV2 swapper, ILevSwapperV2 levSwapper) {
        address safe = constants.getAddress("mainnet.safe.ops");
        IConvexWrapperFactory wrapperFactory = IConvexWrapperFactory(constants.getAddress("mainnet.convex.abraWrapperFactory"));
        IBentoBoxV1 box = IBentoBoxV1(constants.getAddress("mainnet.degenBox"));
        IERC20 mim = IERC20(constants.getAddress("mainnet.mim"));
        address exchange = constants.getAddress("mainnet.aggregators.zeroXExchangeProxy");
        address threePool = constants.getAddress("mainnet.curve.3pool.pool");
        address curvePool = constants.getAddress("mainnet.curve.mim3pool.pool");
        address threePoolZapper = constants.getAddress("mainnet.curve.3pool.zapper");
        IConvexWrapper wrapper = IConvexWrapper(wrapperFactory.CreateWrapper(40));

        IERC20[] memory tokens = new IERC20[](4);
        tokens[0] = IERC20(ICurvePool(curvePool).coins(0));
        tokens[1] = IERC20(ICurvePool(threePool).coins(0));
        tokens[2] = IERC20(ICurvePool(threePool).coins(1));
        tokens[3] = IERC20(ICurvePool(threePool).coins(2));

        swapper = new ConvexWrapperSwapper(box, wrapper, mim, CurvePoolInterfaceType.ICURVE_3POOL_ZAPPER, curvePool, threePoolZapper, tokens, exchange);
        levSwapper = new ConvexWrapperLevSwapper(
            box,
            wrapper,
            mim,
            CurvePoolInterfaceType.ICURVE_3POOL_ZAPPER,
            curvePool,
            threePoolZapper,
            tokens,
            exchange
        );

        oracle = new ProxyOracle();
        //oracle.changeOracleImplementation(IOracle(new ConvexWrapperOracle()));

        if (!testing) {
            oracle.transferOwnership(safe, true, false);
        }
    }
}
