// SPDX-License-Identifier: MIT
// solhint-disable avoid-low-level-calls
pragma solidity >=0.8.0;

import "BoringSolidity/interfaces/IERC20.sol";
import "BoringSolidity/libraries/BoringERC20.sol";
import "interfaces/ISolidlyLpWrapper.sol";
import "interfaces/IBentoBoxV1.sol";
import "interfaces/ILevSwapperV2.sol";
import "interfaces/ISolidlyPair.sol";
import "interfaces/ISolidlyRouter.sol";
import "interfaces/IVelodromePairFactory.sol";
import "libraries/SolidlyOneSidedVolatile.sol";

contract VelodromeVolatileLPLevSwapper is ILevSwapperV2 {
    using BoringERC20 for IERC20;

    error ErrToken0SwapFailed();
    error ErrToken1SwapFailed();

    IBentoBoxV1 public immutable bentoBox;
    ISolidlyLpWrapper public immutable wrapper;
    ISolidlyPair public immutable pair;
    ISolidlyRouter public immutable router;
    IERC20 public immutable mim;
    IERC20 public immutable oneSidingToken;
    IERC20 public immutable token0;
    IERC20 public immutable token1;
    IVelodromePairFactory immutable factory;

    constructor(
        IBentoBoxV1 _bentoBox,
        ISolidlyRouter _router,
        ISolidlyLpWrapper _wrapper,
        IERC20 _mim,
        IVelodromePairFactory _factory,
        bool _oneSideWithToken0
    ) {
        bentoBox = _bentoBox;
        router = _router;
        wrapper = _wrapper;

        ISolidlyPair _pair = ISolidlyPair(address(_wrapper.underlying()));
        mim = _mim;

        IERC20 _token0 = IERC20(_pair.token0());
        IERC20 _token1 = IERC20(_pair.token1());

        oneSidingToken = (_oneSideWithToken0) ? _token0 : _token1;

        IERC20(address(_pair)).approve(address(_wrapper), type(uint256).max);
        _mim.approve(address(_router), type(uint256).max);
        _token0.approve(address(_router), type(uint256).max);
        _token1.approve(address(_router), type(uint256).max);

        pair = _pair;
        token0 = _token0;
        token1 = _token1;
        factory = _factory;
    }

    /// @inheritdoc ILevSwapperV2
    function swap(
        address recipient,
        uint256 shareToMin,
        uint256 shareFrom,
        bytes calldata
    ) external override returns (uint256 extraShare, uint256 shareReturned) {
        bentoBox.withdraw(mim, address(this), address(this), 0, shareFrom);
        uint mimAmount = mim.balanceOf(address(this));

        // MIM -> oneSidingToken
        router.swapExactTokensForTokensSimple(mimAmount, 0, address(mim), address(oneSidingToken), true, address(this), type(uint256).max);

        uint256 liquidity;
        {
            SolidlyOneSidedVolatile.AddLiquidityFromSingleTokenParams memory params = SolidlyOneSidedVolatile
                .AddLiquidityFromSingleTokenParams(
                    router,
                    pair,
                    address(token0),
                    address(token1),
                    pair.reserve0(),
                    pair.reserve1(),
                    address(oneSidingToken),
                    oneSidingToken.balanceOf(address(this)),
                    address(this),
                    factory.volatileFee()
                );

            (, , liquidity) = SolidlyOneSidedVolatile.addLiquidityFromSingleToken(params);
        }

        liquidity = wrapper.enterFor(liquidity, address(bentoBox));

        (, shareReturned) = bentoBox.deposit(IERC20(address(wrapper)), address(bentoBox), recipient, liquidity, 0);
        extraShare = shareReturned - shareToMin;
    }
}
