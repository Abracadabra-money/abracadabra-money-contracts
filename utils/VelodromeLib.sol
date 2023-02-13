// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "periphery/VelodromeVolatileLpHarvester.sol";
import "tokens/SolidlyLpWrapper.sol";
import "swappers/VelodromeVolatileLPSwapper.sol";
import "swappers/VelodromeVolatileLPLevSwapper.sol";

library VelodromeLib {
    function deployWrappedLp(
        ISolidlyPair pair,
        ISolidlyRouter router,
        IVelodromePairFactory factory
    ) internal returns (SolidlyLpWrapper wrapper) {
        string memory name = string.concat("Abracadabra-", pair.name());
        string memory symbol = string.concat("Abra-", pair.name());
        uint8 decimals = pair.decimals();

        wrapper = new SolidlyLpWrapper(ISolidlyPair(pair), name, symbol, decimals);

        VelodromeVolatileLpHarvester harvester = new VelodromeVolatileLpHarvester(router, pair, factory);

        wrapper.setHarvester(harvester);
    }

    function deployVolatileLpSwappers(
        IBentoBoxV1 degenBox,
        ISolidlyRouter router,
        ISolidlyLpWrapper collateral,
        IERC20 mim,
        IVelodromePairFactory factory,
        VelodromeVolatileLPSwapperSwap[] memory deleverageSwaps,
        bool leverageOneSideWithToken0
    ) internal returns (ISwapperV2 swapper, ILevSwapperV2 levSwapper) {
        swapper = ISwapperV2(address(new VelodromeVolatileLPSwapper(degenBox, collateral, mim, router, deleverageSwaps)));
        levSwapper = ILevSwapperV2(address(new VelodromeVolatileLPLevSwapper(degenBox, router, collateral, mim, factory, leverageOneSideWithToken0)));
    }
}
