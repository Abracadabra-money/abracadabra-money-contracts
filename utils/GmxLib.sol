// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "oracles/ProxyOracle.sol";
import "interfaces/IBentoBoxV1.sol";
import "interfaces/ISwapperV2.sol";
import "interfaces/ILevSwapperV2.sol";
import "swappers/GmxLevSwapper.sol";

library GmxLib {
        function deploySwappers(
        IBentoBoxV1 degenBox,
        IERC20 fsGlp,
        IERC20 mim,
        address aggregatorProxy
    ) internal returns (ISwapperV2 swapper, ILevSwapperV2 levSwapper) {
        //swapper = ISwapperV2(address(new ZeroXSolidlyLikeVolatileLPSwapper(degenBox, collateral, mim, aggregatorProxy)));
        levSwapper = ILevSwapperV2(
            address(new GmxLevSwapper(degenBox, fsGlp, mim, aggregatorProxy))
        );
    }
}
