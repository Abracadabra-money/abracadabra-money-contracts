// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {ProxyOracle} from "oracles/ProxyOracle.sol";
import {IOracle} from "interfaces/IOracle.sol";
import {ISwapperV2} from "interfaces/ISwapperV2.sol";
import {ILevSwapperV2} from "interfaces/ILevSwapperV2.sol";
import {CurvePoolInterfaceType} from "interfaces/ICurvePool.sol";

contract YvTricryptoUSDTScript is BaseScript {
    function deploy() public returns (ISwapperV2 swapper, ILevSwapperV2 levSwapper) {
        if (block.chainid != ChainId.Mainnet) {
            revert("only mainnet");
        }
        address box = toolkit.getAddress(block.chainid, "degenBox");
        address mim = toolkit.getAddress(block.chainid, "mim");
        address safe = toolkit.getAddress(block.chainid, "safe.ops");
        address vault = toolkit.getAddress(block.chainid, "yearn.yvTricryptoUSDT");
        address pool = toolkit.getAddress(block.chainid, "curve.tricryptousdt.token");
        address zeroXExchangeProxy = toolkit.getAddress(block.chainid, "aggregators.zeroXExchangeProxy");

        vm.startBroadcast();
        ProxyOracle oracle = ProxyOracle(deploy("ProxyOracle", "ProxyOracle.sol:ProxyOracle"));
        IOracle impl = IOracle(
            deploy("YearnTriCryptoUSDTOracle", "YearnTriCryptoOracle.sol:YearnTriCryptoOracle", abi.encode(vault, pool))
        );

        address[] memory poolTokens = new address[](3);
        poolTokens[0] = toolkit.getAddress(block.chainid, "usdt");
        poolTokens[1] = toolkit.getAddress(block.chainid, "wbtc");
        poolTokens[2] = toolkit.getAddress(block.chainid, "weth");

        swapper = ISwapperV2(
            deploy(
                "YvTricryptoUSDTCurveSwapper",
                "YearnCurveSwapper.sol:YearnCurveSwapper",
                abi.encode(box, vault, mim, CurvePoolInterfaceType.IFACTORY_POOL, pool, address(0), poolTokens, zeroXExchangeProxy)
            )
        );
        levSwapper = ILevSwapperV2(
            deploy(
                "YvTricryptoUSDTCurveLevSwapper",
                "YearnCurveLevSwapper.sol:YearnCurveLevSwapper",
                abi.encode(box, vault, mim, CurvePoolInterfaceType.IFACTORY_POOL, pool, address(0), poolTokens, zeroXExchangeProxy)
            )
        );

        if (oracle.oracleImplementation() != impl) {
            oracle.changeOracleImplementation(impl);
        }

        if (!testing()) {
            if (oracle.owner() != safe) {
                oracle.transferOwnership(safe, true, false);
            }
        }

        vm.stopBroadcast();
    }
}
