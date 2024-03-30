// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import "oracles/ProxyOracle.sol";
import "utils/CauldronDeployLib.sol";
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

struct TokenInfo {
    uint8 decimals;
    address cauldron;
    address token;
    string name;
    uint256 ltvBips;
    uint256 interestBips;
    uint256 borrowFeeBips;
    uint256 liquidationFeeBips;
}

struct Deployement {
    uint8 decimals;
    string name;
    address cauldron;
    address token;
    address swapper;
    address levSwapper;
}

contract MigrationCauldronsScript is BaseScript {
    TokenInfo[] public configs;
    Deployement[] public deployments;

    constructor() {
        configs.push(
            TokenInfo(
                18,
                0x920D9BD936Da4eAFb5E25c6bDC9f6CB528953F9f,
                0xa258C4606Ca8206D8aA700cE2143D7db854D168c,
                "yvWETH-v2",
                8000,
                0,
                5,
                750
            )
        );
        configs.push(
            TokenInfo(
                18,
                0xEBfDe87310dc22404d918058FAa4D56DC4E93f0A,
                0x27b7b1ad7288079A66d12350c828D3C00A6F07d7,
                "yvcrvIB",
                9000,
                150,
                5,
                700
            )
        );
        configs.push(
            TokenInfo(
                6,
                0x551a7CfF4de931F32893c928bBc3D25bF1Fc5147,
                0x7Da96a3891Add058AdA2E826306D812C638D87a7,
                "yvUSDT-v2",
                9000,
                80,
                5,
                300
            )
        );
        configs.push(
            TokenInfo(
                6,
                0x6cbAFEE1FaB76cA5B5e144c43B3B50d42b7C8c8f,
                0x5f18C75AbDAe578b483E5F43f12a39cF75b973a9,
                "yvUSDC-v2",
                9000,
                80,
                5,
                300
            )
        );
        configs.push(
            TokenInfo(
                18,
                0x3410297D89dCDAf4072B805EFc1ef701Bb3dd9BF,
                0x26FA3fFFB6EfE8c1E69103aCb4044C26B9A106a9,
                "sSPELL",
                8000,
                50,
                5,
                1000
            )
        );
    }

    function deploy() public {
        if (block.chainid != ChainId.Mainnet) {
            revert("Unsupported chain");
        }

        address safe = toolkit.getAddress("mainnet.safe.ops");
        address exchange = toolkit.getAddress("mainnet.aggregators.zeroXExchangeProxy");

        IBentoBoxV1 box = IBentoBoxV1(toolkit.getAddress("mainnet.degenBox"));

        vm.startBroadcast();

        for (uint i; i < configs.length; i++) {
            TokenInfo memory token = configs[i];

            // reusing existing oracles
            ProxyOracle oracle = ProxyOracle(deploy(string.concat("ProxyOracle", token.name), "ProxyOracle.sol:ProxyOracle", ""));
            IOracle oracleImpl = ICauldronV4(token.cauldron).oracle();
            bytes memory oracleData = ICauldronV4(token.cauldron).oracleData();

            if (oracle.oracleImplementation() != oracleImpl) {
                oracle.changeOracleImplementation(oracleImpl);
            }

            address cauldron = address(
                CauldronDeployLib.deployCauldronV4(
                    string.concat("Mainnet_privileged_Cauldron", token.name),
                    box,
                    toolkit.getAddress("mainnet.privilegedCauldronV4"),
                    IERC20(token.token),
                    oracle,
                    oracleData,
                    token.ltvBips,
                    token.interestBips,
                    token.borrowFeeBips,
                    token.liquidationFeeBips
                )
            );

            if (!testing()) {
                if (oracle.owner() != safe) {
                    oracle.transferOwnership(safe);
                }
            }

            deployments.push(Deployement(token.decimals, token.name, cauldron, token.token, address(0), address(0)));
        }

        _deployTricrypto(exchange);
        _deploy3Pool(exchange);
        _deployYvWETHSwappers(exchange);

        vm.stopBroadcast();
    }

    // Convex Curve USDT​+WBTC​+ETH pool
    function _deployTricrypto(
        address exchange
    ) internal returns (ProxyOracle oracle, ISwapperV2 swapper, ILevSwapperV2 levSwapper, IConvexWrapper wrapper, ICauldronV4 cauldron) {
        IBentoBoxV1 box = IBentoBoxV1(toolkit.getAddress("mainnet.degenBox"));
        address safe = toolkit.getAddress("mainnet.safe.ops");

        {
            //IConvexWrapperFactory wrapperFactory = IConvexWrapperFactory(toolkit.getAddress("mainnet.convex.abraWrapperFactory"));
            //wrapper = IConvexWrapper(wrapperFactory.CreateWrapper(38));
            wrapper = IConvexWrapper(toolkit.getAddress("mainnet.convex.abraWrapperFactory.tricrypto"));
        }

        (swapper, levSwapper) = _deploTricryptoPoolSwappers(box, wrapper, exchange);

        // reusing existing Tricrypto oracle
        oracle = ProxyOracle(deploy("ProxyOracleCheckpointTricrypto", "ProxyOracle.sol:ProxyOracle", ""));

        IOracle impl = IOracle(0x9732D3Ee0f185D7c2D610E30DC5de28EF68Ad7c9);
        if (oracle.oracleImplementation() != impl) {
            oracle.changeOracleImplementation(impl);
        }

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

        deploy("DegenBoxConvexWrapperTricrypto", "DegenBoxConvexWrapper.sol:DegenBoxConvexWrapper", abi.encode(box, wrapper));

        if (!testing()) {
            if (oracle.owner() != safe) {
                oracle.transferOwnership(safe);
            }
        }

        deployments.push(Deployement(18, "cvxTricrypto", address(cauldron), address(wrapper), address(swapper), address(levSwapper)));
    }

    // Convex privileged Curve 3Pool
    function _deploy3Pool(
        address exchange
    ) internal returns (ProxyOracle oracle, ISwapperV2 swapper, ILevSwapperV2 levSwapper, IConvexWrapper wrapper, ICauldronV4 cauldron) {
        IBentoBoxV1 box = IBentoBoxV1(toolkit.getAddress("mainnet.degenBox"));
        address safe = toolkit.getAddress("mainnet.safe.ops");

        {
            //IConvexWrapperFactory wrapperFactory = IConvexWrapperFactory(toolkit.getAddress("mainnet.convex.abraWrapperFactory"));
            //wrapper = IConvexWrapper(wrapperFactory.CreateWrapper(9));
            wrapper = IConvexWrapper(toolkit.getAddress("mainnet.convex.abraWrapperFactory.3pool"));
        }
        (swapper, levSwapper) = _deployPoolSwappers(box, wrapper, exchange);

        oracle = ProxyOracle(deploy("ProxyOracleCheckpointCvx3Pool", "ProxyOracle.sol:ProxyOracle", ""));

        // We can leave out MIM here as it always has a 1 USD (1 MIM) value.
        IAggregator[] memory aggregators = new IAggregator[](3);
        aggregators[0] = IAggregator(toolkit.getAddress("mainnet.chainlink.dai"));
        aggregators[1] = IAggregator(toolkit.getAddress("mainnet.chainlink.usdc"));
        aggregators[2] = IAggregator(toolkit.getAddress("mainnet.chainlink.usdt"));

        IOracle impl = IOracle(0x13f193d5328d967076c5ED80Be9ed5a79224DdAb);
        if (oracle.oracleImplementation() != impl) {
            oracle.changeOracleImplementation(impl);
        }

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

        deploy("DegenBoxConvexWrapper3Pool", "DegenBoxConvexWrapper.sol:DegenBoxConvexWrapper", abi.encode(box, wrapper));

        if (!testing()) {
            if (oracle.owner() != safe) {
                oracle.transferOwnership(safe);
            }
        }

        deployments.push(Deployement(18, "cvx3Pool", address(cauldron), address(wrapper), address(swapper), address(levSwapper)));
    }

    function _deploTricryptoPoolSwappers(
        IBentoBoxV1 box,
        IConvexWrapper wrapper,
        address exchange
    ) internal returns (ISwapperV2 swapper, ILevSwapperV2 levSwapper) {
        address curvePool = toolkit.getAddress("mainnet.curve.tricrypto.pool");
        address[] memory _tokens = new address[](3);
        _tokens[0] = ICurvePool(curvePool).coins(0);
        _tokens[1] = ICurvePool(curvePool).coins(1);
        _tokens[2] = ICurvePool(curvePool).coins(2);

        swapper = ConvexWrapperSwapper(
            deploy(
                "ConvexWrapperSwapperTricrypto",
                "ConvexWrapperSwapper.sol:ConvexWrapperSwapper",
                abi.encode(
                    box,
                    wrapper,
                    toolkit.getAddress("mainnet.mim"),
                    CurvePoolInterfaceType.ITRICRYPTO_POOL,
                    curvePool,
                    address(0),
                    _tokens,
                    exchange
                )
            )
        );

        levSwapper = ConvexWrapperLevSwapper(
            deploy(
                "ConvexWrapperLevSwapperTricrypto",
                "ConvexWrapperLevSwapper.sol:ConvexWrapperLevSwapper",
                abi.encode(
                    box,
                    wrapper,
                    toolkit.getAddress("mainnet.mim"),
                    CurvePoolInterfaceType.ITRICRYPTO_POOL,
                    curvePool,
                    address(0),
                    _tokens,
                    exchange
                )
            )
        );
    }

    function _deployPoolSwappers(
        IBentoBoxV1 box,
        IConvexWrapper wrapper,
        address exchange
    ) internal returns (ISwapperV2 swapper, ILevSwapperV2 levSwapper) {
        address curvePool = toolkit.getAddress("mainnet.curve.3pool.pool");
        address[] memory _tokens = new address[](3);

        {
            _tokens[0] = ICurvePool(curvePool).coins(0);
            _tokens[1] = ICurvePool(curvePool).coins(1);
            _tokens[2] = ICurvePool(curvePool).coins(2);
        }

        swapper = ConvexWrapperSwapper(
            deploy(
                "ConvexWrapperSwapper3Pool",
                "ConvexWrapperSwapper.sol:ConvexWrapperSwapper",
                abi.encode(
                    box,
                    wrapper,
                    toolkit.getAddress("mainnet.mim"),
                    CurvePoolInterfaceType.ICURVE_POOL,
                    curvePool,
                    address(0),
                    _tokens,
                    exchange
                )
            )
        );

        levSwapper = ConvexWrapperLevSwapper(
            deploy(
                "ConvexWrapperLevSwapper3Pool",
                "ConvexWrapperLevSwapper.sol:ConvexWrapperLevSwapper",
                abi.encode(
                    box,
                    wrapper,
                    toolkit.getAddress("mainnet.mim"),
                    CurvePoolInterfaceType.ICURVE_POOL,
                    curvePool,
                    address(0),
                    _tokens,
                    exchange
                )
            )
        );
    }

    function _deployYvWETHSwappers(address exchange) internal returns (ISwapperV2 swapper, ILevSwapperV2 levSwapper) {
        IBentoBoxV1 box = IBentoBoxV1(toolkit.getAddress("mainnet.degenBox"));
        address vault = toolkit.getAddress("mainnet.yearn.yvWETH");

        swapper = ISwapperV2(
            deploy("YvWethSwapper", "YearnSwapper.sol:YearnSwapper", abi.encode(box, vault, toolkit.getAddress("mainnet.mim"), exchange))
        );

        levSwapper = ILevSwapperV2(
            deploy(
                "YvWethLevSwapper",
                "YearnLevSwapper.sol:YearnLevSwapper",
                abi.encode(box, vault, toolkit.getAddress("mainnet.mim"), exchange)
            )
        );
    }

    function getDeployments() public view returns (Deployement[] memory) {
        return deployments;
    }
}
