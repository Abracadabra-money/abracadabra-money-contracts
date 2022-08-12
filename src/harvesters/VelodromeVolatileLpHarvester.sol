// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "interfaces/ISolidlyPair.sol";
import "interfaces/ISolidlyRouter.sol";
import "interfaces/IVaultHarvester.sol";
import "interfaces/IVelodromePairFactory.sol";
import "libraries/SolidlyOneSidedVolatile.sol";

contract VelodromeVolatileLpHarvester is IVaultHarvester {
    ISolidlyPair public immutable pair;
    ISolidlyRouter public immutable router;
    IVelodromePairFactory immutable factory;
    address public immutable token0;
    address public immutable token1;

    constructor(
        ISolidlyRouter _router,
        ISolidlyPair _pair,
        IVelodromePairFactory _factory
    ) {
        factory = _factory;
        pair = _pair;
        router = _router;
        (token0, token1) = _pair.tokens();
    }

    function harvest(address recipient) external {
        SolidlyOneSidedVolatile.AddLiquidityAndOneSideRemainingParams memory params = SolidlyOneSidedVolatile
            .AddLiquidityAndOneSideRemainingParams(
                router,
                pair,
                address(token0),
                address(token1),
                pair.reserve0(),
                pair.reserve1(),
                IERC20(token0).balanceOf(address(this)),
                IERC20(token1).balanceOf(address(this)),
                0,
                0,
                recipient,
                factory.volatileFee()
            );

        SolidlyOneSidedVolatile.addLiquidityAndOneSideRemaining(params);
    }
}
