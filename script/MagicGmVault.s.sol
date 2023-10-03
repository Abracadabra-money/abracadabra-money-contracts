// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {IMagicGm, IMagicGmRouterOrder, IGmxV2ExchangeRouter} from "periphery/MagicGmRouter.sol";

contract MagicGmVaultScript is BaseScript {
    using DeployerFunctions for Deployer;

    function deploy() public returns (MagicGmRouter router) {
        address usdc = toolkit.getAddress(block.chainid, "usdc");
        address gmBtc = toolkit.getAddress(block.chainid, "gmx.v2.gmBTC");
        address gmEth = toolkit.getAddress(block.chainid, "gmx.v2.gmETH");
        address gmArb = toolkit.getAddress(block.chainid, "gmx.v2.gmARB");
        IGmxV2ExchangeRouter gmxRouter = IGmxV2ExchangeRouter(toolkit.getAddress(block.chainid, "gmx.v2.exchangeRouter"));
        address syntheticsRouter = toolkit.getAddress(block.chainid, "gmx.v2.syntheticsRouter");

        IMagicGmRouterOrder orderImpl = deployer.deploy_MagicGmRouterOrder(
            toolkit.prefixWithChainName(block.chainid, "MagicGmRouterOrderImpl"),
            IMagicGm(address(0)),
            usdc,
            gmBtc,
            gmEth,
            gmArb,
            toolkit.getAddress(block.chainid, "wbtc"),
            toolkit.getAddress(block.chainid, "weth"),
            toolkit.getAddress(block.chainid, "arb"),
            gmxRouter,
            syntheticsRouter
        );

        router = deployer.deploy_MagicGmRouter(toolkit.prefixWithChainName(block.chainid, "MagicGmRouter"), orderImpl);
    }
}
