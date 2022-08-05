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
import "interfaces/IBentoBoxV1.sol";
import "interfaces/IUniswapV2Pair.sol";
import "interfaces/ISolidlyPair.sol";
import "interfaces/IUniswapV2Router01.sol";
import "interfaces/ISolidlyRouter.sol";

abstract contract BaseScript is Script {
    Constants internal immutable constants = new Constants();
    bool internal testing;

    function setTesting(bool _testing) public {
        testing = _testing;
    }

    function deployDegenBox(address weth) public returns (DegenBox) {
        return new DegenBox(IERC20(weth));
    }

    function deployCauldronV3MasterContract(address degenBox, address mim) public returns (CauldronV3_2) {
        return new CauldronV3_2(IBentoBoxV1(degenBox), IERC20(mim));
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
    ) public returns (CauldronV3_2) {
        bytes memory data = abi.encode(
            collateral,
            oracle,
            oracleData,
            (interestBips * 316880878) / 100, // 316880878 is the precomputed integral part of 1e18 / (36525 * 3600 * 24)
            liquidationFeeBips * 1e1 + 1e5,
            uint64(ltvBips * 1e1),
            borrowFeeBips * 1e1
        );

        return CauldronV3_2(IBentoBoxV1(degenBox).deploy(masterContract, data, true));
    }

    function deployUniswapLikeZeroExSwappers(
        address degenBox,
        address uniswapLikeRouter,
        address collateral,
        address mim,
        address zeroXExchangeProxy
    ) public returns (ZeroXUniswapLikeLPSwapper, ZeroXUniswapLikeLPLevSwapper) {
        return (
            new ZeroXUniswapLikeLPSwapper(IBentoBoxV1(degenBox), IUniswapV2Pair(collateral), ERC20(mim), zeroXExchangeProxy),
            new ZeroXUniswapLikeLPLevSwapper(
                IBentoBoxV1(degenBox),
                IUniswapV2Router01(uniswapLikeRouter),
                IUniswapV2Pair(collateral),
                ERC20(mim),
                zeroXExchangeProxy
            )
        );
    }

    function deploySolidlyLikeVolatileZeroExSwappers(
        address degenBox,
        address uniswapLikeRouter,
        address collateral,
        address mim,
        address zeroXExchangeProxy
    ) public returns (ZeroXUniswapLikeLPSwapper, ZeroXSolidlyLikeVolatileLPLevSwapper) {
        return (
            new ZeroXUniswapLikeLPSwapper(IBentoBoxV1(degenBox), IUniswapV2Pair(collateral), ERC20(mim), zeroXExchangeProxy),
            new ZeroXSolidlyLikeVolatileLPLevSwapper(
                IBentoBoxV1(degenBox),
                ISolidlyRouter(uniswapLikeRouter),
                ISolidlyPair(collateral),
                ERC20(mim),
                zeroXExchangeProxy
            )
        );
    }

    function deployLPOracle(string memory desc, address lp, address tokenAOracle, address tokenBOracle) public  returns (ProxyOracle proxy) {
        proxy = new ProxyOracle();
        TokenOracle tokenOracle = new TokenOracle(IAggregator(tokenAOracle), IAggregator(tokenBOracle));
        LPChainlinkOracle lpChainlinkOracle = new LPChainlinkOracle(IUniswapV2Pair(lp), IAggregator(tokenOracle));
        InvertedLPOracle invertedLpOracle = new InvertedLPOracle(IAggregator(lpChainlinkOracle), IAggregator(tokenBOracle), desc);
        proxy.changeOracleImplementation(invertedLpOracle);
    }
}
