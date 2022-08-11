// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "BoringSolidity/interfaces/IERC20.sol";
import "swappers/ZeroXSolidlyLikeVolatileLPLevSwapper.sol";
import "swappers/ZeroXSolidlyLikeVolatileLPSwapper.sol";
import "strategies/SolidlyGaugeVolatileLPStrategy.sol";
import "interfaces/IBentoBoxV1.sol";
import "interfaces/ISolidlyRouter.sol";
import "interfaces/ISwapperV2.sol";
import "interfaces/ILevSwapperV2.sol";

abstract contract SolidlyLikeScript {
    function deploySolidlyLikeVolatileZeroExSwappers(
        IBentoBoxV1 degenBox,
        ISolidlyRouter router,
        SolidlyLpWrapper collateral,
        ERC20 mim,
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
}
