// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "BoringSolidity/interfaces/IERC20.sol";
import "forge-std/Script.sol";
import "./Constants.sol";
import "/DegenBox.sol";
import "swappers/ZeroXSolidlyLikeVolatileLPLevSwapper.sol";
import "swappers/ZeroXUniswapLikeLPLevSwapper.sol";
import "swappers/ZeroXUniswapLikeLPSwapper.sol";
import "oracles/ProxyOracle.sol";
import "oracles/TokenOracle.sol";
import "oracles/LPChainlinkOracle.sol";
import "oracles/InvertedLPOracle.sol";
import "cauldrons/CauldronV3_2.sol";
import "withdrawers/MultichainWithdrawer.sol";
import "strategies/SolidlyGaugeVolatileLPStrategy.sol";
import "interfaces/IBentoBoxV1.sol";
import "interfaces/IUniswapV2Pair.sol";
import "interfaces/ISolidlyPair.sol";
import "interfaces/IUniswapV2Router01.sol";
import "interfaces/ISolidlyRouter.sol";
import "interfaces/ICauldronV1.sol";
import "interfaces/ICauldronV2.sol";
import "interfaces/ICauldronV3.sol";
import "interfaces/ISwapperV2.sol";
import "interfaces/ILevSwapperV2.sol";
import "interfaces/IAnyswapRouter.sol";

abstract contract BaseScript is Script {
    Constants internal immutable constants = new Constants();
    bool internal testing;

    function deployer() public view returns (address) {
        return tx.origin;
    }

    function setTesting(bool _testing) public {
        testing = _testing;
    }

    function logDeployed(string memory m, address a) internal view {
        if (testing) {
            console.log("Deployed %s: %s", m, a);
        }
    }

    function deployDegenBox(address weth) public returns (IBentoBoxV1) {
        address degenBox = address(new DegenBox(IERC20(weth)));

        logDeployed("DegenBox", degenBox);
        return IBentoBoxV1(degenBox);
    }

    function deployCauldronV3MasterContract(address degenBox, address mim) public returns (ICauldronV3 cauldron) {
        cauldron = ICauldronV3(address(new CauldronV3_2(IBentoBoxV1(degenBox), IERC20(mim))));
        logDeployed("Cauldron V3.2 MasterContract", address(cauldron));
    }

    /// Cauldron percentages parameters are in bips unit
    /// Examples:
    ///  1 = 0.01%
    ///  10_000 = 100%
    ///  250 = 2.5%
    ///
    /// Adapted from original calculation. (variables are % values instead of bips):
    ///  ltv = ltv * 1e3;
    ///  borrowFee = borrowFee * (1e5 / 100);
    ///  interest = interest * (1e18 / (365.25 * 3600 * 24) / 100);
    ///  liquidationFee = liquidationFee * 1e3 + 1e5;
    function deployCauldronV3(
        address degenBox,
        address masterContract,
        address collateral,
        address oracle,
        bytes memory oracleData,
        uint256 ltvBips,
        uint256 interestBips,
        uint256 borrowFeeBips,
        uint256 liquidationFeeBips
    ) public returns (ICauldronV3 cauldron) {
        bytes memory data = abi.encode(
            collateral,
            oracle,
            oracleData,
            uint64((interestBips * 316880878) / 100), // 316880878 is the precomputed integral part of 1e18 / (36525 * 3600 * 24)
            liquidationFeeBips * 1e1 + 1e5,
            ltvBips * 1e1,
            borrowFeeBips * 1e1
        );

        cauldron = ICauldronV3(IBentoBoxV1(degenBox).deploy(masterContract, data, true));

        logDeployed("Cauldron V3.2", address(cauldron));
    }

    function deployUniswapLikeZeroExSwappers(
        address degenBox,
        address uniswapLikeRouter,
        address collateral,
        address mim,
        address zeroXExchangeProxy
    ) public returns (ISwapperV2 swapper, ILevSwapperV2 levSwapper) {
        swapper = ISwapperV2(
            address(new ZeroXUniswapLikeLPSwapper(IBentoBoxV1(degenBox), IUniswapV2Pair(collateral), ERC20(mim), zeroXExchangeProxy))
        );
        levSwapper = ILevSwapperV2(
            address(
                new ZeroXUniswapLikeLPLevSwapper(
                    IBentoBoxV1(degenBox),
                    IUniswapV2Router01(uniswapLikeRouter),
                    IUniswapV2Pair(collateral),
                    ERC20(mim),
                    zeroXExchangeProxy
                )
            )
        );

        logDeployed("Swapper", address(swapper));
        logDeployed("LevSwapper", address(levSwapper));
    }

    function deploySolidlyLikeVolatileZeroExSwappers(
        address degenBox,
        address uniswapLikeRouter,
        address collateral,
        address mim,
        address zeroXExchangeProxy
    ) public returns (ISwapperV2 swapper, ILevSwapperV2 levSwapper) {
        swapper = ISwapperV2(
            address(new ZeroXUniswapLikeLPSwapper(IBentoBoxV1(degenBox), IUniswapV2Pair(collateral), ERC20(mim), zeroXExchangeProxy))
        );
        levSwapper = ILevSwapperV2(
            address(
                new ZeroXSolidlyLikeVolatileLPLevSwapper(
                    IBentoBoxV1(degenBox),
                    ISolidlyRouter(uniswapLikeRouter),
                    ISolidlyPair(collateral),
                    ERC20(mim),
                    zeroXExchangeProxy
                )
            )
        );

        logDeployed("Swapper", address(swapper));
        logDeployed("LevSwapper", address(levSwapper));
    }

    function deployLPOracle(
        string memory desc,
        address lp,
        address tokenAOracle,
        address tokenBOracle
    ) public returns (ProxyOracle proxy) {
        proxy = new ProxyOracle();
        TokenOracle tokenOracle = new TokenOracle(IAggregator(tokenAOracle), IAggregator(tokenBOracle));
        LPChainlinkOracle lpChainlinkOracle = new LPChainlinkOracle(IUniswapV2Pair(lp), IAggregator(tokenOracle));
        InvertedLPOracle invertedLpOracle = new InvertedLPOracle(IAggregator(lpChainlinkOracle), IAggregator(tokenBOracle), desc);
        proxy.changeOracleImplementation(invertedLpOracle);

        logDeployed("ProxyOracle", address(proxy));
    }

    function deploySolidlyGaugeVolatileLPStrategy(
        address collateral,
        address degenBox,
        address router,
        address gauge,
        address reward,
        bytes32 initHash,
        bool usePairToken0
    ) public returns (SolidlyGaugeVolatileLPStrategy strategy) {
        strategy = new SolidlyGaugeVolatileLPStrategy(
            ERC20(collateral),
            IBentoBoxV1(degenBox),
            ISolidlyRouter(router),
            ISolidlyGauge(gauge),
            reward,
            initHash,
            usePairToken0
        );

        logDeployed("Strategy", address(strategy));
    }

    function deployMultichainWithdrawer(
        address bentoBox,
        address degenBox,
        address mim,
        address anyswapRouter,
        address mimProvider
    ) public returns (MultichainWithdrawer withdrawer) {
        withdrawer = new MultichainWithdrawer(
            IBentoBoxV1(bentoBox),
            IBentoBoxV1(degenBox),
            ERC20(mim),
            IAnyswapRouter(anyswapRouter),
            mimProvider,
            constants.getAddress("mainnet.ethereumWithdrawer"),
            new ICauldronV2[](0),
            new ICauldronV1[](0),
            new ICauldronV2[](0)
        );

        logDeployed("MultichainWithdrawer", address(withdrawer));
    }
}
