// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/libraries/BoringERC20.sol";
import "interfaces/ISolidlyPair.sol";
import "interfaces/ISolidlyRouter.sol";
import "interfaces/IVaultHarvester.sol";
import "interfaces/IVelodromePairFactory.sol";
import "libraries/SolidlyOneSidedVolatile.sol";

contract VelodromeVolatileLpHarvester is IVaultHarvester {
    using BoringERC20 for IERC20;

    ISolidlyPair public immutable pair;
    ISolidlyRouter public immutable router;
    IVelodromePairFactory immutable factory;
    IERC20 public immutable token0;
    IERC20 public immutable token1;

    constructor(
        ISolidlyRouter _router,
        ISolidlyPair _pair,
        IVelodromePairFactory _factory
    ) {
        factory = _factory;
        pair = _pair;
        router = _router;
        (address _token0, address _token1) = _pair.tokens();

        IERC20(_token0).approve(address(_router), type(uint256).max);
        IERC20(_token1).approve(address(_router), type(uint256).max);

        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
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
                token0.balanceOf(address(this)),
                token1.balanceOf(address(this)),
                0,
                0,
                recipient,
                factory.volatileFee()
            );

        SolidlyOneSidedVolatile.addLiquidityAndOneSideRemaining(params);

        // Return back remaining balances
        token0.safeTransfer(recipient, token0.balanceOf(address(this)));
        token1.safeTransfer(recipient, token1.balanceOf(address(this)));
    }
}
