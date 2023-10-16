// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "oracles/ProxyOracle.sol";
import "oracles/InverseOracle.sol";
import {CurveStablePoolAggregator} from "oracles/aggregators/CurveStablePoolAggregator.sol";
import "interfaces/ISwapperV2.sol";
import "interfaces/ILevSwapperV2.sol";
import "interfaces/IConvexWrapperFactory.sol";
import "interfaces/IConvexWrapper.sol";
import "interfaces/IAggregator.sol";
import "swappers/ConvexWrapperSwapper.sol";
import "swappers/ConvexWrapperLevSwapper.sol";
import "periphery/DegenBoxConvexWrapper.sol";
import "utils/CauldronDeployLib.sol";
import "mixins/Whitelister.sol";
import {WhitelistedCheckpointCauldronV4} from "cauldrons/CheckpointCauldronV4.sol";

contract ConvexCauldronsScript is BaseScript {
    function deploy() public {
        vm.startBroadcast();
        address exchange = toolkit.getAddress("mainnet.aggregators.zeroXExchangeProxy");
        deployTricrypto(exchange);
        deployMimPool(exchange);
        vm.stopBroadcast();
    }

    // Convex Curve USDT​+WBTC​+ETH pool
    function deployTricrypto(
        address exchange
    ) public returns (ProxyOracle oracle, ISwapperV2 swapper, ILevSwapperV2 levSwapper, IConvexWrapper wrapper, ICauldronV4 cauldron) {
        IBentoBoxV1 box = IBentoBoxV1(toolkit.getAddress("mainnet.degenBox"));

        {
            IConvexWrapperFactory wrapperFactory = IConvexWrapperFactory(toolkit.getAddress("mainnet.convex.abraWrapperFactory"));
            wrapper = IConvexWrapper(wrapperFactory.CreateWrapper(38));
        }

        (swapper, levSwapper) = _deploTricryptoPoolSwappers(box, wrapper, exchange);

        // reusing existing Tricrypto oracle
        oracle = ProxyOracle(0x9732D3Ee0f185D7c2D610E30DC5de28EF68Ad7c9);

        cauldron = CauldronDeployLib.deployCauldronV4(
            deployer,
            "Mainnet_Convex_Tricrypto_Cauldron",
            box,
            toolkit.getAddress("mainnet.checkpointCauldronV4"),
            IERC20(address(wrapper)),
            oracle,
            "",
            9000, // 90% ltv
            650, // 6.5% interests
            50, // 0.5% opening
            500 // 5% liquidation
        );

        new DegenBoxConvexWrapper(box, wrapper);

        //if (!testing()) {
        //    address safe = toolkit.getAddress("mainnet.safe.ops");
        //    oracle.transferOwnership(safe, true, false);
        //}
    }

    function _deploTricryptoPoolSwappers(
        IBentoBoxV1 box,
        IConvexWrapper wrapper,
        address exchange
    ) private returns (ISwapperV2 swapper, ILevSwapperV2 levSwapper) {
        address curvePool = toolkit.getAddress("mainnet.curve.tricrypto.pool");
        IERC20[] memory tokens = new IERC20[](3);
        tokens[0] = IERC20(ICurvePool(curvePool).coins(0));
        tokens[1] = IERC20(ICurvePool(curvePool).coins(1));
        tokens[2] = IERC20(ICurvePool(curvePool).coins(2));

        swapper = new ConvexWrapperSwapper(
            box,
            wrapper,
            IERC20(toolkit.getAddress("mainnet.mim")),
            CurvePoolInterfaceType.ITRICRYPTO_POOL,
            curvePool,
            address(0),
            tokens,
            exchange
        );
        levSwapper = new ConvexWrapperLevSwapper(
            box,
            wrapper,
            IERC20(toolkit.getAddress("mainnet.mim")),
            CurvePoolInterfaceType.ITRICRYPTO_POOL,
            curvePool,
            address(0),
            tokens,
            exchange
        );
    }

    // Convex Whitelisted Curve MIM3Pool
    function deployMimPool(
        address exchange
    ) public returns (ProxyOracle oracle, ISwapperV2 swapper, ILevSwapperV2 levSwapper, IConvexWrapper wrapper, ICauldronV4 cauldron) {
        IBentoBoxV1 box = IBentoBoxV1(toolkit.getAddress("mainnet.degenBox"));
        address safe = toolkit.getAddress("mainnet.safe.ops");

        {
            IConvexWrapperFactory wrapperFactory = IConvexWrapperFactory(toolkit.getAddress("mainnet.convex.abraWrapperFactory"));
            wrapper = IConvexWrapper(wrapperFactory.CreateWrapper(40));
        }
        (swapper, levSwapper) = _deployMimPoolSwappers(box, wrapper, exchange);

        oracle = new ProxyOracle();

        // We can leave out MIM here as it always has a 1 USD (1 MIM) value.
        IAggregator[] memory aggregators = new IAggregator[](3);
        aggregators[0] = IAggregator(toolkit.getAddress("mainnet.chainlink.dai"));
        aggregators[1] = IAggregator(toolkit.getAddress("mainnet.chainlink.usdc"));
        aggregators[2] = IAggregator(toolkit.getAddress("mainnet.chainlink.usdt"));

        IOracle impl = IOracle(
            new InverseOracle(
                "MIM3CRV",
                new CurveStablePoolAggregator(ICurvePool(toolkit.getAddress("mainnet.curve.mim3pool.pool")), aggregators),
                0
            )
        );

        oracle.changeOracleImplementation(impl);

        cauldron = CauldronDeployLib.deployCauldronV4(
            deployer,
            "Mainnet_Convex_MIM3CRV_Cauldron",
            box,
            toolkit.getAddress("mainnet.whitelistedCheckpointCauldronV4"),
            IERC20(address(wrapper)),
            oracle,
            "",
            9800, // 98% ltv
            100, // 1% interests
            0, // 0% opening
            50 // 0.5% liquidation
        );

        new DegenBoxConvexWrapper(box, wrapper);

        Whitelister whitelister = new Whitelister(bytes32(0), "");
        whitelister.setMaxBorrowOwner(safe, type(uint256).max);

        // Should be done by the master contract owner
        //WhitelistedCheckpointCauldronV4(address(cauldron)).changeWhitelister(whitelister);

        if (!testing()) {
            oracle.transferOwnership(safe, true, false);
            whitelister.transferOwnership(safe, true, false);
        }
    }

    function _deployMimPoolSwappers(
        IBentoBoxV1 box,
        IConvexWrapper wrapper,
        address exchange
    ) private returns (ISwapperV2 swapper, ILevSwapperV2 levSwapper) {
        address curvePool = toolkit.getAddress("mainnet.curve.mim3pool.pool");
        address threePoolZapper = toolkit.getAddress("mainnet.curve.3pool.zapper");

        IERC20[] memory tokens = new IERC20[](4);
        tokens[0] = IERC20(ICurvePool(curvePool).coins(0));

        address threePool = toolkit.getAddress("mainnet.curve.3pool.pool");
        tokens[1] = IERC20(ICurvePool(threePool).coins(0));
        tokens[2] = IERC20(ICurvePool(threePool).coins(1));
        tokens[3] = IERC20(ICurvePool(threePool).coins(2));

        swapper = new ConvexWrapperSwapper(
            box,
            wrapper,
            IERC20(toolkit.getAddress("mainnet.mim")),
            CurvePoolInterfaceType.ICURVE_3POOL_ZAPPER,
            curvePool,
            threePoolZapper,
            tokens,
            exchange
        );
        levSwapper = new ConvexWrapperLevSwapper(
            box,
            wrapper,
            IERC20(toolkit.getAddress("mainnet.mim")),
            CurvePoolInterfaceType.ICURVE_3POOL_ZAPPER,
            curvePool,
            threePoolZapper,
            tokens,
            exchange
        );
    }
}
