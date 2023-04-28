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
        address exchange = constants.getAddress("mainnet.aggregators.zeroXExchangeProxy");
        deployTricrypto(exchange);
        deployMimPool(exchange);
        stopBroadcast();
    }

    // Convex Curve USDT​+WBTC​+ETH pool
    function deployTricrypto(
        address exchange
    ) public returns (ProxyOracle oracle, ISwapperV2 swapper, ILevSwapperV2 levSwapper, IConvexWrapper wrapper) {
        IBentoBoxV1 box = IBentoBoxV1(constants.getAddress("mainnet.degenBox"));
        address curvePool = constants.getAddress("mainnet.curve.tricrypto.pool");

        {
            IConvexWrapperFactory wrapperFactory = IConvexWrapperFactory(constants.getAddress("mainnet.convex.abraWrapperFactory"));
            wrapper = IConvexWrapper(wrapperFactory.CreateWrapper(38));
        }

        IERC20[] memory tokens = new IERC20[](3);
        tokens[0] = IERC20(ICurvePool(curvePool).coins(0));
        tokens[1] = IERC20(ICurvePool(curvePool).coins(1));
        tokens[2] = IERC20(ICurvePool(curvePool).coins(2));

        swapper = new ConvexWrapperSwapper(
            box,
            wrapper,
            IERC20(constants.getAddress("mainnet.mim")),
            CurvePoolInterfaceType.ITRICRYPTO_POOL,
            curvePool,
            address(0),
            tokens,
            exchange
        );
        levSwapper = new ConvexWrapperLevSwapper(
            box,
            wrapper,
            IERC20(constants.getAddress("mainnet.mim")),
            CurvePoolInterfaceType.ITRICRYPTO_POOL,
            curvePool,
            address(0),
            tokens,
            exchange
        );

        oracle = new ProxyOracle();
        //oracle.changeOracleImplementation(IOracle(new ConvexWrapperOracle()));

        if (!testing) {
            address safe = constants.getAddress("mainnet.safe.ops");
            oracle.transferOwnership(safe, true, false);
        }
    }

    // Convex Curve USDT​+WBTC​+ETH pool
    function deployMimPool(
        address exchange
    ) public returns (ProxyOracle oracle, ISwapperV2 swapper, ILevSwapperV2 levSwapper, IConvexWrapper wrapper) {
        IBentoBoxV1 box = IBentoBoxV1(constants.getAddress("mainnet.degenBox"));
        address curvePool = constants.getAddress("mainnet.curve.mim3pool.pool");
        address threePoolZapper = constants.getAddress("mainnet.curve.3pool.zapper");

        {
            IConvexWrapperFactory wrapperFactory = IConvexWrapperFactory(constants.getAddress("mainnet.convex.abraWrapperFactory"));
            wrapper = IConvexWrapper(wrapperFactory.CreateWrapper(40));
        }

        IERC20[] memory tokens = new IERC20[](4);
        tokens[0] = IERC20(ICurvePool(curvePool).coins(0));

        {
            address threePool = constants.getAddress("mainnet.curve.3pool.pool");
            tokens[1] = IERC20(ICurvePool(threePool).coins(0));
            tokens[2] = IERC20(ICurvePool(threePool).coins(1));
            tokens[3] = IERC20(ICurvePool(threePool).coins(2));
        }

        swapper = new ConvexWrapperSwapper(
            box,
            wrapper,
            IERC20(constants.getAddress("mainnet.mim")),
            CurvePoolInterfaceType.ICURVE_3POOL_ZAPPER,
            curvePool,
            threePoolZapper,
            tokens,
            exchange
        );
        levSwapper = new ConvexWrapperLevSwapper(
            box,
            wrapper,
            IERC20(constants.getAddress("mainnet.mim")),
            CurvePoolInterfaceType.ICURVE_3POOL_ZAPPER,
            curvePool,
            threePoolZapper,
            tokens,
            exchange
        );

        oracle = new ProxyOracle();
        //oracle.changeOracleImplementation(IOracle(new ConvexWrapperOracle()));

        if (!testing) {
            address safe = constants.getAddress("mainnet.safe.ops");
            oracle.transferOwnership(safe, true, false);
        }
    }
}
