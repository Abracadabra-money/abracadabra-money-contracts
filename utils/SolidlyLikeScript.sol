// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "BoringSolidity/interfaces/IERC20.sol";
import "swappers/ZeroXSolidlyLikeVolatileLPLevSwapper.sol";
import "swappers/ZeroXUniswapLikeLPSwapper.sol";
import "strategies/SolidlyGaugeVolatileLPStrategy.sol";
import "interfaces/IBentoBoxV1.sol";
import "interfaces/ISolidlyPair.sol";
import "interfaces/ISolidlyRouter.sol";
import "interfaces/ISwapperV2.sol";
import "interfaces/ILevSwapperV2.sol";

abstract contract SolidlyLikeScript {
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
    }
}
