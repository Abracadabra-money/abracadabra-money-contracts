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
import {ICurvePool} from "interfaces/ICurvePool.sol";

contract ConvexPrivilegedCauldronsScript is BaseScript {
    function deploy() public {
        vm.startBroadcast();
        address exchange = toolkit.getAddress("mainnet.aggregators.zeroXExchangeProxy");
        deployTricrypto(exchange);
        deploy3Pool(exchange);
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
        oracle = ProxyOracle(deploy("ProxyOracleCheckpointTricrypto", "ProxyOracle.sol:ProxyOracle", abi.encode()));
        oracle.changeOracleImplementation(IOracle(0x9732D3Ee0f185D7c2D610E30DC5de28EF68Ad7c9));

        cauldron = CauldronDeployLib.deployCauldronV4(
            "Mainnet_Privileged_Convex_Tricrypto_Cauldron",
            box,
            toolkit.getAddress("mainnet.privilegedCheckpointCauldronV4"),
            IERC20(address(wrapper)),
            oracle,
            "",
            9000, // 90% ltv
            350, // 3.5% interests
            50, // 0.5% opening
            500 // 5% liquidation
        );

        new DegenBoxConvexWrapper(box, wrapper);
    }

    function _deploTricryptoPoolSwappers(
        IBentoBoxV1 box,
        IConvexWrapper wrapper,
        address exchange
    ) private returns (ISwapperV2 swapper, ILevSwapperV2 levSwapper) {
        address curvePool = toolkit.getAddress("mainnet.curve.tricrypto.pool");
        address[] memory tokens = new address[](3);
        tokens[0] = ICurvePool(curvePool).coins(0);
        tokens[1] = ICurvePool(curvePool).coins(1);
        tokens[2] = ICurvePool(curvePool).coins(2);

        swapper = ConvexWrapperSwapper(deploy("ConvexWrapperSwapperTricrypto", "ConvexWrapperSwapper.sol:ConvexWrapperSwapper", abi.encode(box, wrapper, toolkit.getAddress("mainnet.mim"), CurvePoolInterfaceType.ITRICRYPTO_POOL, curvePool, address(0), tokens, exchange)));
        
        levSwapper = ConvexWrapperLevSwapper(deploy("ConvexWrapperLevSwapperTricrypto", "ConvexWrapperLevSwapper.sol:ConvexWrapperLevSwapper", abi.encode(box, wrapper, toolkit.getAddress("mainnet.mim"), CurvePoolInterfaceType.ITRICRYPTO_POOL, curvePool, address(0), tokens, exchange)));
        
    }

    // Convex privileged Curve 3Pool
    function deploy3Pool(
        address exchange
    ) public returns (ProxyOracle oracle, ISwapperV2 swapper, ILevSwapperV2 levSwapper, IConvexWrapper wrapper, ICauldronV4 cauldron) {
        IBentoBoxV1 box = IBentoBoxV1(toolkit.getAddress("mainnet.degenBox"));
        address safe = toolkit.getAddress("mainnet.safe.ops");

        {
            IConvexWrapperFactory wrapperFactory = IConvexWrapperFactory(toolkit.getAddress("mainnet.convex.abraWrapperFactory"));
            wrapper = IConvexWrapper(wrapperFactory.CreateWrapper(9));
        }
        (swapper, levSwapper) = _deployPoolSwappers(box, wrapper, exchange);

        oracle = new ProxyOracle();

        // We can leave out MIM here as it always has a 1 USD (1 MIM) value.
        IAggregator[] memory aggregators = new IAggregator[](3);
        aggregators[0] = IAggregator(toolkit.getAddress("mainnet.chainlink.dai"));
        aggregators[1] = IAggregator(toolkit.getAddress("mainnet.chainlink.usdc"));
        aggregators[2] = IAggregator(toolkit.getAddress("mainnet.chainlink.usdt"));

        IOracle impl = IOracle(0x13f193d5328d967076c5ED80Be9ed5a79224DdAb);

        oracle.changeOracleImplementation(impl);

        cauldron = CauldronDeployLib.deployCauldronV4(
            "Mainnet_Privileged_Convex_3CRV_Cauldron",
            box,
            toolkit.getAddress("mainnet.privilegedCheckpointCauldronV4"),
            IERC20(address(wrapper)),
            oracle,
            "",
            9200, // 92% ltv
            50, // 0.5% interests
            50, // 0.5% opening
            50 // 0.5% liquidation
        );

        new DegenBoxConvexWrapper(box, wrapper);

        // Should be done by the master contract owner
        //WhitelistedCheckpointCauldronV4(address(cauldron)).changeWhitelister(whitelister);

        if (!testing()) {
            oracle.transferOwnership(safe);
        }
    }

    function _deployPoolSwappers(
        IBentoBoxV1 box,
        IConvexWrapper wrapper,
        address exchange
    ) private returns (ISwapperV2 swapper, ILevSwapperV2 levSwapper) {
        address curvePool = toolkit.getAddress("mainnet.curve.mim3pool.pool");
        address threePoolZapper = toolkit.getAddress("mainnet.curve.3pool.zapper");

        address[] memory tokens = new address[](3);

        address threePool = toolkit.getAddress("mainnet.curve.3pool.pool");
        tokens[0] = ICurvePool(threePool).coins(0);
        tokens[1] = ICurvePool(threePool).coins(1);
        tokens[2] = ICurvePool(threePool).coins(2);

        swapper = ConvexWrapperSwapper(deploy("ConvexWrapperSwapper3Pool", "ConvexWrapperSwapper.sol:ConvexWrapperSwapper", abi.encode(box, wrapper, toolkit.getAddress("mainnet.mim"), CurvePoolInterfaceType.ICURVE_3POOL_ZAPPER, curvePool, threePoolZapper, tokens, exchange)));
        
        levSwapper = ConvexWrapperLevSwapper(deploy("ConvexWrapperLevSwapper3Pool", "ConvexWrapperLevSwapper.sol:ConvexWrapperLevSwapper", abi.encode(box, wrapper, toolkit.getAddress("mainnet.mim"), CurvePoolInterfaceType.ICURVE_3POOL_ZAPPER, curvePool, threePoolZapper, tokens, exchange)));
        
    }
}
