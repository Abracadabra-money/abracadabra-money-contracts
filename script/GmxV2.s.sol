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

contract GmxV2Script is BaseScript {
    using DeployerFunctions for Deployer;

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
            IGmCauldronOrderAgent _orderAgent,
            MarketDeployment memory gmETHDeployment,
            MarketDeployment memory gmBTCDeployment,
            MarketDeployment memory gmARBDeployment
        )
    {
        if (block.chainid != ChainId.Arbitrum) {
            revert("Wrong chain");
        }

        deployer.setAutoBroadcast(false);
        vm.startBroadcast();

        box = IBentoBoxV1(toolkit.getAddress(block.chainid, "degenBox"));
        safe = toolkit.getAddress(block.chainid, "safe.ops");

        IERC20 mim = IERC20(toolkit.getAddress(block.chainid, "mim"));
        IGmxV2ExchangeRouter router = IGmxV2ExchangeRouter(toolkit.getAddress(block.chainid, "gmx.v2.exchangeRouter"));
        address syntheticsRouter = toolkit.getAddress(block.chainid, "gmx.v2.syntheticsRouter");
        IGmxReader reader = IGmxReader(toolkit.getAddress(block.chainid, "gmx.v2.reader"));

        GmxV2CauldronRouterOrder routerOrderImpl = deployer.deploy_GmxV2CauldronRouterOrder(
            toolkit.prefixWithChainName(block.chainid, "GmxV2CauldronRouterOrderImpl"),
            router,
            syntheticsRouter,
            reader
        );

        orderAgent = _orderAgent = IGmCauldronOrderAgent(
            address(
                deployer.deploy_GmxV2CauldronOrderAgent(
                    toolkit.prefixWithChainName(block.chainid, "GmxV2CauldronOrderAgent"),
                    address(routerOrderImpl)
                )
            )
        );

        // Deploy GMX Cauldron MasterContract
        masterContract = address(
            deployer.deploy_GmxV2CauldronV4(toolkit.prefixWithChainName(block.chainid, "GmxV2CauldronV4_MC"), box, mim)
        );

        gmETHDeployment = _deployMarket(
            "ETH",
            toolkit.getAddress(block.chainid, "gmx.v2.gmETH"),
            IAggregator(toolkit.getAddress(block.chainid, "chainlink.eth"))
        );
        gmBTCDeployment = _deployMarket(
            "BTC",
            toolkit.getAddress(block.chainid, "gmx.v2.gmBTC"),
            IAggregator(toolkit.getAddress(block.chainid, "chainlink.btc"))
        );
        gmARBDeployment = _deployMarket(
            "ARB",
            toolkit.getAddress(block.chainid, "gmx.v2.gmARB"),
            IAggregator(toolkit.getAddress(block.chainid, "chainlink.arb"))
        );

        vm.stopBroadcast();
    }

    // chainlinkMarketUnderlyingToken = Aggregator(toolkit.getAddress(block.chainid, "chainlink.eth"))
    // marketToken = toolkit.getAddress(block.chainid, "gmx.v2.gmETH")
    function _deployMarket(
        string memory marketName,
        address marketToken,
        IAggregator chainlinkMarketUnderlyingToken
    ) private returns (MarketDeployment memory marketDeployment) {
        ProxyOracle oracle = deployer.deploy_ProxyOracle(
            toolkit.prefixWithChainName(block.chainid, string.concat("GmProxyOracle_", marketName))
        );
        oracle.changeOracleImplementation(
            IOracle(
                address(
                    deployer.deploy_GmOracleWithAggregator(
                        toolkit.prefixWithChainName(block.chainid, string.concat("GmOracle_", marketName)),
                        IGmxReader(toolkit.getAddress(block.chainid, "gmx.v2.reader")),
                        chainlinkMarketUnderlyingToken,
                        IAggregator(toolkit.getAddress(block.chainid, "chainlink.usdc")),
                        marketToken,
                        toolkit.getAddress(block.chainid, "gmx.v2.dataStore"),
                        string.concat("gm", marketName, "/USD")
                    )
                )
            )
        );

        ICauldronV4 cauldron = CauldronDeployLib.deployCauldronV4(
            deployer,
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

        if (!testing()) {
            BoringOwnable(address(cauldron)).transferOwnership(safe, true, false);
        }

        marketDeployment = MarketDeployment(oracle, cauldron);
    }
}
