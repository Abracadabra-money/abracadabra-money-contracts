// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {CurvePoolInterfaceType} from "/interfaces/ICurvePool.sol";
import {ICurvePool} from "/interfaces/ICurvePool.sol";
import {ChainId} from "utils/Toolkit.sol";

contract NewSwappersV2Script is BaseScript {
    address mim = toolkit.getAddress("mim");
    address box = toolkit.getAddress("degenBox");
    address weth = toolkit.getAddress("weth");

    function deploy() public {
        vm.startBroadcast();

        if (block.chainid == ChainId.Mainnet) {
            _deployConvexTricrypto();
            _deployConvex3Pool();
            _deployYvWeth();
            _deployStargateUSDT();
        }

        if (block.chainid == ChainId.Arbitrum) {
            _deployWETH();
            _deployMagicGlp();
        }

        vm.stopBroadcast();
    }

    function _deployConvexTricrypto() internal {
        address convexWrapper = toolkit.getAddress("convex.abraWrapperFactory.tricrypto");
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
        address convexWrapper = toolkit.getAddress("convex.abraWrapperFactory.3pool");
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
            abi.encode(box, convexWrapper, mim, CurvePoolInterfaceType.ICURVE_POOL, curvePool, address(0), _tokens)
        );

        deploy(
            "ConvexWrapperLevSwapper3Pool",
            "ConvexWrapperLevSwapper.sol:ConvexWrapperLevSwapper",
            abi.encode(box, convexWrapper, mim, CurvePoolInterfaceType.ICURVE_POOL, curvePool, address(0), _tokens)
        );
    }

    function _deployYvWeth() internal {
        address vault = toolkit.getAddress("yearn.yvWETH");
        deploy("YvWethSwapper", "YearnSwapper.sol:YearnSwapper", abi.encode(box, vault, mim));
        deploy("YvWethLevSwapper", "YearnLevSwapper.sol:YearnLevSwapper", abi.encode(box, vault, mim));
    }

    function _deployStargateUSDT() internal {
        address stargateRouter = toolkit.getAddress("stargate.router");
        address pool = toolkit.getAddress("stargate.usdtPool");
        uint256 poolId = 2;
        deploy(
            "StargateUSDTLevSwapper",
            "StargateLPLevSwapper.sol:StargateLPLevSwapper",
            abi.encode(box, pool, poolId, stargateRouter, mim)
        );
        deploy("StargateUSDTSwapper", "StargateLPSwapper.sol:StargateLPSwapper", abi.encode(box, pool, poolId, stargateRouter, mim));
    }

    function _deployWETH() internal {
        deploy("WETHLevSwapper", "TokenLevSwapper.sol:TokenLevSwapper", abi.encode(box, weth, mim));
        deploy("WETHSwapper", "TokenSwapper.sol:TokenSwapper", abi.encode(box, weth, mim));
    }

    function _deployMagicGlp() internal {
        address magicGlp = toolkit.getAddress("magicGlp");
        address gmxVault = toolkit.getAddress("gmx.vault");
        address sGLP = toolkit.getAddress("gmx.sGLP");
        address glpManager = toolkit.getAddress("gmx.glpManager");
        address glpRewardRouter = toolkit.getAddress("gmx.glpRewardRouter");

        deploy(
            "MagicGlpLevSwapper",
            "MagicGlpLevSwapper.sol:MagicGlpLevSwapper",
            abi.encode(box, gmxVault, magicGlp, mim, sGLP, glpManager, glpRewardRouter)
        );
        deploy("MagicGlpSwapper", "MagicGlpSwapper.sol:MagicGlpSwapper", abi.encode(box, gmxVault, magicGlp, mim, sGLP, glpRewardRouter));
    }
}
