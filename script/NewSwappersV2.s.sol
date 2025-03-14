// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {CurvePoolInterfaceType} from "/interfaces/ICurvePool.sol";
import {ICurvePool} from "/interfaces/ICurvePool.sol";

contract NewSwappersV2Script is BaseScript {
    address mim = toolkit.getAddress("mim");
    address box = toolkit.getAddress("degenBox");
    address wrapper = toolkit.getAddress("convex.abraWrapperFactory.tricrypto");
    address curvePool = toolkit.getAddress("curve.tricrypto.pool");

    function deploy() public {
        vm.startBroadcast();

        _deployConvexTricrypto();

        vm.stopBroadcast();
    }

    function _deployConvexTricrypto() internal {
        address[] memory _tokens = new address[](3);
        _tokens[0] = ICurvePool(curvePool).coins(0);
        _tokens[1] = ICurvePool(curvePool).coins(1);
        _tokens[2] = ICurvePool(curvePool).coins(2);

        deploy(
            "ConvexWrapperSwapperTricrypto",
            "ConvexWrapperSwapper.sol:ConvexWrapperSwapper",
            abi.encode(box, wrapper, mim, CurvePoolInterfaceType.ITRICRYPTO_POOL, curvePool, address(0), _tokens)
        );
        deploy(
            "ConvexWrapperLevSwapperTricrypto",
            "ConvexWrapperLevSwapper.sol:ConvexWrapperLevSwapper",
            abi.encode(box, wrapper, mim, CurvePoolInterfaceType.ITRICRYPTO_POOL, curvePool, address(0), _tokens)
        );
    }
}
