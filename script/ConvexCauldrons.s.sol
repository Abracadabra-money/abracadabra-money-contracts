// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "oracles/ProxyOracle.sol";
import "oracles/CurveMeta3PoolOracle.sol";
import "interfaces/ISwapperV2.sol";
import "interfaces/ILevSwapperV2.sol";
import "interfaces/IConvexWrapperFactory.sol";
import "interfaces/IConvexWrapper.sol";
import "swappers/ConvexWrapperSwapper.sol";
import "swappers/ConvexWrapperLevSwapper.sol";
import "periphery/DegenBoxConvexWrapper.sol";
import "utils/CauldronDeployLib.sol";

contract ConvexCauldronsScript is BaseScript {
    function deploy() public {
        startBroadcast();
        address exchange = constants.getAddress("mainnet.aggregators.zeroXExchangeProxy");
        deployTricrypto(exchange);
        deployMimPool(exchange);
        stopBroadcast();
    }

    // Convex Curve USDT​+WBTC​+ETH pool
    function deployTricrypto(
        address exchange
    ) public returns (ProxyOracle oracle, ISwapperV2 swapper, ILevSwapperV2 levSwapper, IConvexWrapper wrapper, ICauldronV4 cauldron) {
        IBentoBoxV1 box = IBentoBoxV1(constants.getAddress("mainnet.degenBox"));

        {
            IConvexWrapperFactory wrapperFactory = IConvexWrapperFactory(constants.getAddress("mainnet.convex.abraWrapperFactory"));
            wrapper = IConvexWrapper(wrapperFactory.CreateWrapper(38));
        }

        (swapper, levSwapper) = _deploTricryptoPoolSwappers(box, wrapper, exchange);

        // reusing existing Tricrypto oracle
        oracle = ProxyOracle(0x9732D3Ee0f185D7c2D610E30DC5de28EF68Ad7c9);

        cauldron = CauldronDeployLib.deployCauldronV4(
            box,
            constants.getAddress("mainnet.checkpointCauldronV4"),
            IERC20(address(wrapper)),
            oracle,
            "",
            9200, // 92% ltv
            150, // 1.5% interests
            100, // 1% opening
            400 // 4% liquidation
        );

        new DegenBoxConvexWrapper(box, wrapper);

        //if (!testing) {
        //    address safe = constants.getAddress("mainnet.safe.ops");
        //    oracle.transferOwnership(safe, true, false);
        //}
    }

    function _deploTricryptoPoolSwappers(
        IBentoBoxV1 box,
        IConvexWrapper wrapper,
        address exchange
    ) private returns (ISwapperV2 swapper, ILevSwapperV2 levSwapper) {
        address curvePool = constants.getAddress("mainnet.curve.tricrypto.pool");
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
    }

    // Convex Curve USDT​+WBTC​+ETH pool
    function deployMimPool(
        address exchange
    ) public returns (ProxyOracle oracle, ISwapperV2 swapper, ILevSwapperV2 levSwapper, IConvexWrapper wrapper, ICauldronV4 cauldron) {
        IBentoBoxV1 box = IBentoBoxV1(constants.getAddress("mainnet.degenBox"));

        {
            IConvexWrapperFactory wrapperFactory = IConvexWrapperFactory(constants.getAddress("mainnet.convex.abraWrapperFactory"));
            wrapper = IConvexWrapper(wrapperFactory.CreateWrapper(40));
        }
        (swapper, levSwapper) = _deployMimPoolSwappers(box, wrapper, exchange);

        oracle = new ProxyOracle();
        IOracle impl = IOracle(
            new CurveMeta3PoolOracle(
                "MIM3CRV",
                ICurvePool(constants.getAddress("mainnet.curve.mim3pool.pool")),
                IAggregator(address(0)), // We can leave out MIM here as it always has a 1 USD (1 MIM) value.
                IAggregator(constants.getAddress("mainnet.chainlink.dai")),
                IAggregator(constants.getAddress("mainnet.chainlink.usdc")),
                IAggregator(constants.getAddress("mainnet.chainlink.usdt"))
            )
        );

        oracle.changeOracleImplementation(impl);

        cauldron = CauldronDeployLib.deployCauldronV4(
            box,
            constants.getAddress("mainnet.checkpointCauldronV4"),
            IERC20(address(wrapper)),
            oracle,
            "",
            9200, // 92% ltv
            150, // 1.5% interests
            100, // 1% opening
            400 // 4% liquidation
        );

        new DegenBoxConvexWrapper(box, wrapper);

        if (!testing) {
            address safe = constants.getAddress("mainnet.safe.ops");
            oracle.transferOwnership(safe, true, false);
        }
    }

    function _deployMimPoolSwappers(
        IBentoBoxV1 box,
        IConvexWrapper wrapper,
        address exchange
    ) private returns (ISwapperV2 swapper, ILevSwapperV2 levSwapper) {
        address curvePool = constants.getAddress("mainnet.curve.mim3pool.pool");
        address threePoolZapper = constants.getAddress("mainnet.curve.3pool.zapper");

        IERC20[] memory tokens = new IERC20[](4);
        tokens[0] = IERC20(ICurvePool(curvePool).coins(0));

        address threePool = constants.getAddress("mainnet.curve.3pool.pool");
        tokens[1] = IERC20(ICurvePool(threePool).coins(0));
        tokens[2] = IERC20(ICurvePool(threePool).coins(1));
        tokens[3] = IERC20(ICurvePool(threePool).coins(2));

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
    }
}
