// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {CurvePoolInterfaceType} from "/interfaces/ICurvePool.sol";
import {ICurvePool} from "/interfaces/ICurvePool.sol";

contract NewSwappersV2Script is BaseScript {
    address mim = toolkit.getAddress("mim");
    address box = toolkit.getAddress("degenBox");
    address convexWrapper = toolkit.getAddress("convex.abraWrapperFactory.tricrypto");

    function deploy() public {
        vm.startBroadcast();

        //_deployConvexTricrypto();
        _deployConvex3Pool();
        //_deployYvWethSwappers();

        vm.stopBroadcast();
    }

    function _deployConvexTricrypto() internal {
        address curvePool = toolkit.getAddress("curve.tricrypto.pool");

        address[] memory _tokens = new address[](3);
        _tokens[0] = ICurvePool(curvePool).coins(0);
        _tokens[1] = ICurvePool(curvePool).coins(1);
        _tokens[2] = ICurvePool(curvePool).coins(2);

        deploy(
            "ConvexWrapperSwapperTricrypto",
            "ConvexWrapperSwapper.sol:ConvexWrapperSwapper",
            abi.encode(box, convexWrapper, mim, CurvePoolInterfaceType.ITRICRYPTO_POOL, curvePool, address(0), _tokens)
        );
        deploy(
            "ConvexWrapperLevSwapperTricrypto",
            "ConvexWrapperLevSwapper.sol:ConvexWrapperLevSwapper",
            abi.encode(box, convexWrapper, mim, CurvePoolInterfaceType.ITRICRYPTO_POOL, curvePool, address(0), _tokens)
        );
    }

    function _deployConvex3Pool() internal {
        address curvePool = toolkit.getAddress("curve.3pool.pool");
        address[] memory _tokens = new address[](3);
        {
            _tokens[0] = ICurvePool(curvePool).coins(0);
            _tokens[1] = ICurvePool(curvePool).coins(1);
            _tokens[2] = ICurvePool(curvePool).coins(2);
        }

        deploy(
            "ConvexWrapperSwapper3Pool",
            "ConvexWrapperSwapper.sol:ConvexWrapperSwapper",
            abi.encode(box, convexWrapper, mim, CurvePoolInterfaceType.ICURVE_POOL_LEGACY, curvePool, address(0), _tokens)
        );

        deploy(
            "ConvexWrapperLevSwapper3Pool",
            "ConvexWrapperLevSwapper.sol:ConvexWrapperLevSwapper",
            abi.encode(box, convexWrapper, mim, CurvePoolInterfaceType.ICURVE_POOL_LEGACY, curvePool, address(0), _tokens)
        );
    }

    function _deployYvWethSwappers() internal {
        address vault = toolkit.getAddress("yearn.yvWETH");
        deploy("YvWethSwapper", "YearnSwapper.sol:YearnSwapper", abi.encode(box, vault, mim));
        deploy("YvWethLevSwapper", "YearnLevSwapper.sol:YearnLevSwapper", abi.encode(box, vault, mim));
    }
}
