// SPDX-License-Identifier: MIT
// solhint-disable avoid-low-level-calls
pragma solidity >=0.8.0;

import "BoringSolidity/interfaces/IERC20.sol";
import "BoringSolidity/libraries/BoringERC20.sol";
import "libraries/SafeApprove.sol";
import "interfaces/IBentoBoxV1.sol";
import "interfaces/ILevSwapperV2.sol";
import "interfaces/IConvexWrapper.sol";
import "interfaces/ICurvePool.sol";

contract ConvexWrapperLevSwapper is ILevSwapperV2 {
    using BoringERC20 for IERC20;
    using SafeApprove for IERC20;

    error ErrSwapFailed();
    error ErrUnsupportedCurvePoolLength();

    CurvePoolInterfaceType public immutable curvePoolInterfaceType;
    IBentoBoxV1 public immutable bentoBox;
    IERC20 public immutable mim;
    IERC20 public immutable curveToken;
    IConvexWrapper public immutable wrapper;
    address public immutable zeroXExchangeProxy;
    ICurvePool public immutable curvePool;
    uint256 public immutable curvePoolCoinsLength;

    constructor(
        IBentoBoxV1 _bentoBox,
        IConvexWrapper _wrapper,
        IERC20 _mim,
        CurvePoolInterfaceType _curvePoolInterfaceType,
        ICurvePool _curvePool,
        uint96 _curvePoolCoinsLength,
        address _zeroXExchangeProxy
    ) {
        bentoBox = _bentoBox;
        wrapper = _wrapper;
        mim = _mim;
        curvePoolInterfaceType = _curvePoolInterfaceType;
        curvePool = _curvePool;
        zeroXExchangeProxy = _zeroXExchangeProxy;
        curvePoolCoinsLength = _curvePoolCoinsLength;

        IERC20 _curveToken = IERC20(_wrapper.curveToken());
        _curveToken.safeApprove(address(_wrapper), type(uint256).max);

        _mim.approve(_zeroXExchangeProxy, type(uint256).max);
        curveToken = _curveToken;

        for (uint256 i = 0; i < _curvePoolCoinsLength; i++) {
            IERC20(ICurvePool(_curvePool).coins(i)).safeApprove(address(_curvePool), type(uint256).max);
        }
    }

    /// @inheritdoc ILevSwapperV2
    function swap(
        address recipient,
        uint256 shareToMin,
        uint256 shareFrom,
        bytes calldata data
    ) external override returns (uint256 extraShare, uint256 shareReturned) {
        (uint256 poolIndex, bytes memory swapData) = abi.decode(data, (uint256, bytes));
        IERC20 underlyingToken = IERC20(ICurvePool(curvePool).coins(poolIndex));

        bentoBox.withdraw(mim, address(this), address(this), 0, shareFrom);

        // MIM -> Asset
        (bool success, ) = zeroXExchangeProxy.call(swapData);
        if (!success) {
            revert ErrSwapFailed();
        }

        if (curvePoolCoinsLength == 2) {
            uint256[2] memory amounts;
            amounts[poolIndex] = underlyingToken.balanceOf(address(this));
            curvePool.add_liquidity(amounts, 0);
        } else if (curvePoolCoinsLength == 3) {
            uint256[3] memory amounts;
            amounts[poolIndex] = underlyingToken.balanceOf(address(this));
            curvePool.add_liquidity(amounts, 0);
        } else if (curvePoolCoinsLength == 4) {
            uint256[4] memory amounts;
            amounts[poolIndex] = underlyingToken.balanceOf(address(this));
            curvePool.add_liquidity(amounts, 0);
        } else {
            revert ErrUnsupportedCurvePoolLength();
        }

        uint256 _amount = curveToken.balanceOf(address(this));
        wrapper.deposit(_amount, address(bentoBox));

        (, shareReturned) = bentoBox.deposit(IERC20(address(wrapper)), address(bentoBox), recipient, _amount, 0);

        extraShare = shareReturned - shareToMin;
    }
}
