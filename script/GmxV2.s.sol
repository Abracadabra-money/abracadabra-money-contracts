// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {IBentoBoxV1} from "interfaces/IBentoBoxV1.sol";
import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {BoringOwnable} from "BoringSolidity/BoringOwnable.sol";
import {IGmxV2ExchangeRouter, IGmxReader} from "interfaces/IGmxV2.sol";
import {IGmCauldronOrderAgent} from "periphery/GmxV2CauldronOrderAgent.sol";
import {ICauldronV4} from "interfaces/ICauldronV4.sol";
import {IOracle} from "interfaces/IOracle.sol";
import {IAggregator} from "interfaces/IAggregator.sol";
import {CauldronDeployLib} from "utils/CauldronDeployLib.sol";
import {ProxyOracle} from "oracles/ProxyOracle.sol";
import {InverseOracle} from "oracles/InverseOracle.sol";
import {GmxV2CauldronV4} from "cauldrons/GmxV2CauldronV4.sol";
import {GmxV2CauldronRouterOrder, GmxV2CauldronOrderAgent} from "periphery/GmxV2CauldronOrderAgent.sol";
import {OperatableV2} from "mixins/OperatableV2.sol";

contract GmxV2Script is BaseScript {
    struct MarketDeployment {
        ProxyOracle oracle;
        ICauldronV4 cauldron;
    }

    IGmCauldronOrderAgent orderAgent;
    address masterContract;
    IBentoBoxV1 box;
    address safe;

    function deploy()
        public
        returns (
            address _masterContract,
            IGmCauldronOrderAgent _orderAgent,
            MarketDeployment memory gmETHDeployment,
            MarketDeployment memory gmBTCDeployment,
            MarketDeployment memory gmARBDeployment
        )
    {
        if (block.chainid != ChainId.Arbitrum) {
            revert("Wrong chain");
        }

        box = IBentoBoxV1(toolkit.getAddress(block.chainid, "degenBox"));
        safe = toolkit.getAddress(block.chainid, "safe.ops");
        IERC20 mim = IERC20(toolkit.getAddress(block.chainid, "mim"));
        address usdc = toolkit.getAddress(block.chainid, "usdc");
        address weth = toolkit.getAddress(block.chainid, "weth");
        IGmxV2ExchangeRouter router = IGmxV2ExchangeRouter(toolkit.getAddress(block.chainid, "gmx.v2.exchangeRouter"));
        address syntheticsRouter = toolkit.getAddress(block.chainid, "gmx.v2.syntheticsRouter");
        IGmxReader reader = IGmxReader(toolkit.getAddress(block.chainid, "gmx.v2.reader"));

        vm.startBroadcast();
        GmxV2CauldronRouterOrder routerOrderImpl = GmxV2CauldronRouterOrder(
            payable(deploy(
                "GmxV2CauldronRouterOrderImpl",
                "GmxV2CauldronOrderAgent.sol:GmxV2CauldronRouterOrder",
                abi.encode(router, syntheticsRouter, reader, weth)
            ))
        );

        orderAgent = _orderAgent = IGmCauldronOrderAgent(
            deploy(
                "GmxV2CauldronOrderAgent",
                "GmxV2CauldronOrderAgent.sol:GmxV2CauldronOrderAgent",
                abi.encode(box, address(routerOrderImpl), tx.origin)
            )
        );

        InverseOracle usdcOracle = InverseOracle(
            deploy(
                "InverseOracle_USDC",
                "InverseOracle.sol:InverseOracle",
                abi.encode("Inverse USDC/USD", IAggregator(toolkit.getAddress(block.chainid, "chainlink.usdc")), 18)
            )
        );

        orderAgent.setOracle(usdc, usdcOracle);

        // Deploy GMX Cauldron MasterContract
        masterContract = _masterContract = deploy("GmxV2CauldronV4_MC", "GmxV2CauldronV4.sol:GmxV2CauldronV4", abi.encode(box, mim));

        gmETHDeployment = _deployMarket(
            "ETH",
            toolkit.getAddress(block.chainid, "gmx.v2.gmETH"),
            toolkit.getAddress(block.chainid, "weth"),
            IAggregator(toolkit.getAddress(block.chainid, "chainlink.eth"))
        );
        gmBTCDeployment = _deployMarket(
            "BTC",
            toolkit.getAddress(block.chainid, "gmx.v2.gmBTC"),
            toolkit.getAddress(block.chainid, "wbtc"),
            IAggregator(toolkit.getAddress(block.chainid, "chainlink.btc"))
        );
        gmARBDeployment = _deployMarket(
            "ARB",
            toolkit.getAddress(block.chainid, "gmx.v2.gmARB"),
            toolkit.getAddress(block.chainid, "arb"),
            IAggregator(toolkit.getAddress(block.chainid, "chainlink.arb"))
        );

        vm.stopBroadcast();
    }

    function _deployMarket(
        string memory marketName,
        address marketToken,
        address indexToken,
        IAggregator chainlinkMarketUnderlyingToken
    ) private returns (MarketDeployment memory marketDeployment) {
        ProxyOracle oracle = _deployOracle(marketName, marketToken, indexToken, chainlinkMarketUnderlyingToken);

        ICauldronV4 cauldron = CauldronDeployLib.deployCauldronV4(
            toolkit.prefixWithChainName(block.chainid, string.concat("GMXV2Cauldron_", marketName)),
            box,
            masterContract,
            IERC20(marketToken),
            IOracle(address(oracle)),
            "",
            9700, // 97% ltv
            300, // 3% interests
            15, // 0.15% opening
            50 // 0.5% liquidation
        );

        GmxV2CauldronV4(address(cauldron)).setOrderAgent(orderAgent);
        OperatableV2(address(orderAgent)).setOperator(address(cauldron), true);
        
        if (!testing()) {
            BoringOwnable(address(cauldron)).transferOwnership(safe, true, false);
        }

        orderAgent.setOracle(marketToken, oracle);
        marketDeployment = MarketDeployment(oracle, cauldron);
    }

    function _deployOracle(
        string memory marketName,
        address marketToken,
        address indexToken,
        IAggregator chainlinkMarketUnderlyingToken
    ) internal returns (ProxyOracle oracle) {
        oracle = ProxyOracle(deploy(string.concat("GmProxyOracle_", marketName), "ProxyOracle.sol:ProxyOracle"));

        address impl = deploy(
            string.concat("GmOracle_", marketName),
            "GmOracleWithAggregator.sol:GmOracleWithAggregator",
            abi.encode(
                IGmxReader(toolkit.getAddress(block.chainid, "gmx.v2.reader")),
                chainlinkMarketUnderlyingToken,
                IAggregator(toolkit.getAddress(block.chainid, "chainlink.usdc")),
                marketToken,
                indexToken,
                toolkit.getAddress(block.chainid, "gmx.v2.dataStore"),
                string.concat("gm", marketName, "/USD")
            )
        );

        oracle.changeOracleImplementation(IOracle(impl));
    }
}
