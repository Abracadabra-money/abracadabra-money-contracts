// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "BoringSolidity/interfaces/IERC20.sol";
import "oracles/ProxyOracle.sol";
import "oracles/TokenOracle.sol";
import "oracles/UniswapLikeLPOracle.sol";
import "oracles/InvertedOracle.sol";
import "oracles/ERC20VaultOracle.sol";
import "swappers/ZeroXSolidlyLikeVolatileLPLevSwapper.sol";
import "swappers/ZeroXSolidlyLikeVolatileLPSwapper.sol";
import "strategies/SolidlyGaugeVolatileLPStrategy.sol";
import "interfaces/IBentoBoxV1.sol";
import "interfaces/ISolidlyRouter.sol";
import "interfaces/ISwapperV2.sol";
import "interfaces/ILevSwapperV2.sol";
import "interfaces/ISolidlyLpWrapper.sol";

abstract contract SolidlyLikeScript {
    function deploySolidlyLikeVolatileZeroExSwappers(
        IBentoBoxV1 degenBox,
        ISolidlyRouter router,
        ISolidlyLpWrapper collateral,
        IERC20 mim,
        address zeroXExchangeProxy
    ) public returns (ISwapperV2 swapper, ILevSwapperV2 levSwapper) {
        swapper = ISwapperV2(address(new ZeroXSolidlyLikeVolatileLPSwapper(degenBox, collateral, mim, zeroXExchangeProxy)));
        levSwapper = ILevSwapperV2(
            address(new ZeroXSolidlyLikeVolatileLPLevSwapper(degenBox, router, collateral, mim, zeroXExchangeProxy))
        );
    }

    function deploySolidlyGaugeVolatileLPStrategy(
        SolidlyLpWrapper collateral,
        IBentoBoxV1 degenBox,
        ISolidlyRouter router,
        ISolidlyGauge gauge,
        address reward,
        bytes32 initHash,
        bool usePairToken0
    ) public returns (SolidlyGaugeVolatileLPStrategy strategy) {
        strategy = new SolidlyGaugeVolatileLPStrategy(collateral, degenBox, router, gauge, reward, initHash, usePairToken0);
    }

    function deploySolidlyLikeVolatileLPOracle(
        string memory desc,
        ISolidlyLpWrapper wrapper,
        IAggregator tokenAOracle,
        IAggregator tokenBOracle
    ) public returns (ProxyOracle proxy) {
        IUniswapV2Pair lp = IUniswapV2Pair(address(wrapper.underlying()));
        proxy = new ProxyOracle();
        TokenOracle tokenOracle = new TokenOracle(tokenAOracle, tokenBOracle);
        UniswapLikeLPOracle lpOracle = new UniswapLikeLPOracle(lp, tokenOracle);
        ERC20VaultOracle vaultOracle = new ERC20VaultOracle(wrapper, lpOracle);
        InvertedOracle invertedOracle = new InvertedOracle(vaultOracle, tokenBOracle, desc);
        proxy.changeOracleImplementation(invertedOracle);
    }
}
