// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC20} from "@BoringSolidity/interfaces/IERC20.sol";
import {Owned} from "@solmate/auth/Owned.sol";
import "utils/BaseScript.sol";
import {CauldronDeployLib} from "utils/CauldronDeployLib.sol";
import {IBentoBoxV1} from "/interfaces/IBentoBoxV1.sol";
import {ICauldronV4} from "/interfaces/ICauldronV4.sol";
import {IOracle} from "/interfaces/IOracle.sol";
import {IAggregator} from "/interfaces/IAggregator.sol";
import {IGmxV2ExchangeRouter, IGmxReader} from "/interfaces/IGmxV2.sol";
import {IGmCauldronOrderAgent} from "/periphery/GmxV2CauldronOrderAgent.sol";
import {ProxyOracle} from "/oracles/ProxyOracle.sol";
import {ERC20Oracle} from "/oracles/ERC20Oracle.sol";
import {GmxV2CauldronV4} from "/cauldrons/GmxV2CauldronV4.sol";
import {GmxV2CauldronRouterOrder, GmxV2CauldronOrderAgent} from "/periphery/GmxV2CauldronOrderAgent.sol";
import {IOwnableOperators} from "/interfaces/IOwnableOperators.sol";

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
            MarketDeployment memory gmETHSingleSidedDeployment,
            MarketDeployment memory gmBTCDeployment,
            MarketDeployment memory gmBTCSingleSidedDeployment,
            MarketDeployment memory gmARBDeployment,
            MarketDeployment memory gmSOLDeployment,
            MarketDeployment memory gmLINKDeployment
        )
    {
        if (block.chainid != ChainId.Arbitrum) {
            revert("Wrong chain");
        }

        box = IBentoBoxV1(toolkit.getAddress(block.chainid, "degenBox"));
        safe = toolkit.getAddress(block.chainid, "safe.ops");
        IERC20 mim = IERC20(toolkit.getAddress(block.chainid, "mim"));
        address usdc = toolkit.getAddress(block.chainid, "usdc");
        
        IGmxV2ExchangeRouter router = IGmxV2ExchangeRouter(toolkit.getAddress(block.chainid, "gmx.v2.exchangeRouter"));
        address syntheticsRouter = toolkit.getAddress(block.chainid, "gmx.v2.syntheticsRouter");
        IGmxReader reader = IGmxReader(toolkit.getAddress(block.chainid, "gmx.v2.reader"));

        vm.startBroadcast();
        deploy("USDC_MIM_TokenSwapper", "TokenSwapper.sol:TokenSwapper", abi.encode(box, IERC20(usdc), mim));
        deploy("USDC_MIM_LevTokenSwapper", "TokenLevSwapper.sol:TokenLevSwapper", abi.encode(box, IERC20(usdc), mim));

        GmxV2CauldronRouterOrder routerOrderImpl = GmxV2CauldronRouterOrder(
            payable(
                deploy(
                    "GmxV2CauldronRouterOrderImpl",
                    "GmxV2CauldronOrderAgent.sol:GmxV2CauldronRouterOrder",
                    abi.encode(box, router, syntheticsRouter, reader, toolkit.getAddress(block.chainid, "weth"), safe)
                )
            )
        );

        orderAgent = _orderAgent = IGmCauldronOrderAgent(
            deploy(
                "GmxV2CauldronOrderAgent",
                "GmxV2CauldronOrderAgent.sol:GmxV2CauldronOrderAgent",
                abi.encode(box, address(routerOrderImpl), tx.origin)
            )
        );

        // non inverted USDC/USD feed to be used for GmxV2CauldronRouterOrder `orderValueInCollateral`
        {
            ERC20Oracle usdcOracle = ERC20Oracle(
            deploy(
                "ChainLinkOracle_USDC",
                "ERC20Oracle.sol:ERC20Oracle",
                abi.encode("GmxV2CauldronRouterOrder USDC/USD", IAggregator(toolkit.getAddress(block.chainid, "chainlink.usdc")), 0)
             )
            );
            if (orderAgent.oracles(usdc) != IOracle(address(usdcOracle))) {
                orderAgent.setOracle(usdc, usdcOracle);
            }
        }

        {
            ERC20Oracle btcOracle = ERC20Oracle(
            deploy(
                "ChainLinkOracle_BTC",
                "ERC20Oracle.sol:ERC20Oracle",
                abi.encode("GmxV2CauldronRouterOrder BTC/USD", IAggregator(toolkit.getAddress(block.chainid, "chainlink.btc")), 0)
            )
            );
            if (orderAgent.oracles(toolkit.getAddress(block.chainid, "wbtc")) != IOracle(address(btcOracle))) {
                orderAgent.setOracle(toolkit.getAddress(block.chainid, "wbtc"), btcOracle);
            }
        }
        {   
            ERC20Oracle ethOracle = ERC20Oracle(
            deploy(
                "ChainLinkOracle_ETH",
                "ERC20Oracle.sol:ERC20Oracle",
                abi.encode("GmxV2CauldronRouterOrder ETH/USD", IAggregator(toolkit.getAddress(block.chainid, "chainlink.eth")), 0)
            )
            );
            address weth = toolkit.getAddress(block.chainid, "weth");
            if (orderAgent.oracles(weth) != IOracle(address(ethOracle))) {
                orderAgent.setOracle(weth, ethOracle);
            }
        }
        

        

        // Deploy GMX Cauldron MasterContract
        masterContract = _masterContract = deploy(
            "GmxV2CauldronV4_MC",
            "GmxV2CauldronV4.sol:GmxV2CauldronV4",
            abi.encode(box, mim, tx.origin)
        );

        gmETHDeployment = _deployMarket(
            "ETH",
            toolkit.getAddress(block.chainid, "gmx.v2.gmETH"),
            toolkit.getAddress(block.chainid, "weth"),
            IAggregator(toolkit.getAddress(block.chainid, "chainlink.eth")),
            8500, // 85% ltv
            500, // 5% interests
            100, // 1% opening
            600 // 6% liquidation
        );
        gmBTCDeployment = _deployMarket(
            "BTC",
            toolkit.getAddress(block.chainid, "gmx.v2.gmBTC"),
            toolkit.getAddress(block.chainid, "wbtc"),
            IAggregator(toolkit.getAddress(block.chainid, "chainlink.btc")),
            8500, // 85% ltv
            500, // 5% interests
            100, // 1% opening
            600 // 6% liquidation
        );
        gmETHSingleSidedDeployment = _deployMarket(
            "ETH/ETH",
            toolkit.getAddress(block.chainid, "gmx.v2.gmETHSingleSided"),
            toolkit.getAddress(block.chainid, "weth"),
            IAggregator(toolkit.getAddress(block.chainid, "chainlink.eth")),
            8500, // 85% ltv
            800, // 8% interests
            30, // 0.3% opening
            600, // 6% liquidation
            true
        );
        gmBTCSingleSidedDeployment = _deployMarket(
            "BTC/BTC",
            toolkit.getAddress(block.chainid, "gmx.v2.gmBTCSingleSided"),
            toolkit.getAddress(block.chainid, "wbtc"),
            IAggregator(toolkit.getAddress(block.chainid, "chainlink.btc")),
            8500, // 85% ltv
            800, // 8% interests
            30, // 0.3% opening
            600, // 6% liquidation
            true
        );
        gmARBDeployment = _deployMarket(
            "ARB",
            toolkit.getAddress(block.chainid, "gmx.v2.gmARB"),
            toolkit.getAddress(block.chainid, "arb"),
            IAggregator(toolkit.getAddress(block.chainid, "chainlink.arb")),
            7500, // 75% ltv
            420, // 4.2% interests
            100, // 1% opening
            600 // 6% liquidation
        );
        gmSOLDeployment = _deployMarket(
            "SOL",
            toolkit.getAddress(block.chainid, "gmx.v2.gmSOL"),
            toolkit.getAddress(block.chainid, "wsol"),
            IAggregator(toolkit.getAddress(block.chainid, "chainlink.sol")),
            7500, // 75% ltv
            690, // 6.9% interests
            100, // 1% opening
            600 // 6% liquidation
        );
        gmLINKDeployment = _deployMarket(
            "LINK",
            toolkit.getAddress(block.chainid, "gmx.v2.gmLINK"),
            toolkit.getAddress(block.chainid, "link"),
            IAggregator(toolkit.getAddress(block.chainid, "chainlink.link")),
            7000, // 70% ltv
            690, // 6.9% interests
            100, // 1% opening
            600 // 6% liquidation
        );

        if (!IOwnableOperators(address(orderAgent)).operators(address(gmETHDeployment.cauldron))) {
            IOwnableOperators(address(orderAgent)).setOperator(address(gmETHDeployment.cauldron), true);
        }
        if (!IOwnableOperators(address(orderAgent)).operators(address(gmBTCDeployment.cauldron))) {
            IOwnableOperators(address(orderAgent)).setOperator(address(gmBTCDeployment.cauldron), true);
        }
        if (!IOwnableOperators(address(orderAgent)).operators(address(gmBTCSingleSidedDeployment.cauldron))) {
            IOwnableOperators(address(orderAgent)).setOperator(address(gmBTCSingleSidedDeployment.cauldron), true);
        }
        if (!IOwnableOperators(address(orderAgent)).operators(address(gmETHSingleSidedDeployment.cauldron))) {
            IOwnableOperators(address(orderAgent)).setOperator(address(gmETHSingleSidedDeployment.cauldron), true);
        }
        if (!IOwnableOperators(address(orderAgent)).operators(address(gmARBDeployment.cauldron))) {
            IOwnableOperators(address(orderAgent)).setOperator(address(gmARBDeployment.cauldron), true);
        }
        if (!IOwnableOperators(address(orderAgent)).operators(address(gmSOLDeployment.cauldron))) {
            IOwnableOperators(address(orderAgent)).setOperator(address(gmSOLDeployment.cauldron), true);
        }
        if (!IOwnableOperators(address(orderAgent)).operators(address(gmLINKDeployment.cauldron))) {
            IOwnableOperators(address(orderAgent)).setOperator(address(gmLINKDeployment.cauldron), true);
        }

        if (!testing()) {
            if (Owned(address(masterContract)).owner() == tx.origin) {
                Owned(address(masterContract)).transferOwnership(safe);
            }

            if (Owned(address(orderAgent)).owner() == tx.origin) {
                Owned(address(orderAgent)).transferOwnership(safe);
            }
        }

        vm.stopBroadcast();
    }

    function _deployMarket(
        string memory marketName,
        address marketToken,
        address indexToken,
        IAggregator chainlinkMarketUnderlyingToken,
        uint256 ltv,
        uint256 interests,
        uint256 openingFee,
        uint256 liquidationFee
    ) private returns (MarketDeployment memory marketDeployment) {
        return _deployMarket(marketName, marketToken, indexToken, chainlinkMarketUnderlyingToken, ltv, interests, openingFee, liquidationFee, false);
    }

    function _deployMarket(
        string memory marketName,
        address marketToken,
        address indexToken,
        IAggregator chainlinkMarketUnderlyingToken,
        uint256 ltv,
        uint256 interests,
        uint256 openingFee,
        uint256 liquidationFee,
        bool singleSided
    ) private returns (MarketDeployment memory marketDeployment) {
        if (testing()) {
            ltv = 7500;
            interests = 500;
            openingFee = 50;
            liquidationFee = 600;
        }

        ProxyOracle oracle = _deployOracle(marketName, marketToken, indexToken, chainlinkMarketUnderlyingToken, singleSided);

        ICauldronV4 cauldron = CauldronDeployLib.deployCauldronV4(
            string.concat("GMXV2Cauldron_", marketName),
            box,
            masterContract,
            IERC20(marketToken),
            IOracle(address(oracle)),
            "",
            ltv,
            interests,
            openingFee,
            liquidationFee
        );

        /// @dev These following transactions will need to be executed by gnosis safe
        /// for all new market deployed after orderAgent deployment
        /// 1. setOrderAgent on the Cauldron
        /// 2. setOperator true for the new cauldron, on the OrderAgent
        /// 3. setOracle for the gm tokens proxy oracle, on the OrderAgent
        if (!testing()) {
            if (
                address(GmxV2CauldronV4(address(cauldron)).orderAgent()) != address(orderAgent) &&
                Owned(address(ICauldronV4(address(cauldron)).masterContract())).owner() == tx.origin
            ) {
                GmxV2CauldronV4(address(cauldron)).setOrderAgent(orderAgent);
            }

            if (Owned(address(oracle)).owner() == tx.origin) {
                Owned(address(oracle)).transferOwnership(safe);
            }
        } else {
            GmxV2CauldronV4(address(cauldron)).setOrderAgent(orderAgent);
        }

        if (Owned(address(orderAgent)).owner() == tx.origin) {
            if (!IOwnableOperators(address(orderAgent)).operators(address(cauldron))) {
                IOwnableOperators(address(orderAgent)).setOperator(address(cauldron), true);
            }

            if (orderAgent.oracles(marketToken) != IOracle(address(marketToken))) {
                orderAgent.setOracle(marketToken, oracle);
            }
        }

        marketDeployment = MarketDeployment(oracle, cauldron);
    }

    function _deployOracle(
        string memory marketName,
        address marketToken,
        address indexToken,
        IAggregator chainlinkMarketUnderlyingToken
    ) internal returns (ProxyOracle oracle) {
        return _deployOracle(marketName, marketToken, indexToken, chainlinkMarketUnderlyingToken, false);
    }

    function _deployOracle(
        string memory marketName,
        address marketToken,
        address indexToken,
        IAggregator chainlinkMarketUnderlyingToken,
        bool singleSided
    ) internal returns (ProxyOracle oracle) {
        oracle = ProxyOracle(deploy(string.concat("GmProxyOracle_", marketName), "ProxyOracle.sol:ProxyOracle"));

        address impl = deploy(
            string.concat("GmOracle_", marketName),
            "GmOracleWithAggregator.sol:GmOracleWithAggregator",
            abi.encode(
                IGmxReader(toolkit.getAddress(block.chainid, "gmx.v2.reader")),
                chainlinkMarketUnderlyingToken,
                singleSided ? chainlinkMarketUnderlyingToken: IAggregator(toolkit.getAddress(block.chainid, "chainlink.usdc")),
                marketToken,
                indexToken,
                toolkit.getAddress(block.chainid, "gmx.v2.dataStore"),
                string.concat("gm", marketName, "/USD")
            )
        );

        if (oracle.oracleImplementation() != IOracle(impl)) {
            oracle.changeOracleImplementation(IOracle(impl));
        }
    }
}
