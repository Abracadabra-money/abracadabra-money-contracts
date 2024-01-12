// SPDX-License-Identifier: MIT
// solhint-disable avoid-low-level-calls
pragma solidity >=0.8.0;

import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IBentoBoxV1} from "interfaces/IBentoBoxV1.sol";
import {ISwapperV2} from "interfaces/ISwapperV2.sol";
import {IBerachainBex} from "interfaces/IBerachainBex.sol";

contract BexLpSwapper is ISwapperV2 {
    using SafeTransferLib for address;

    error ErrSwapFailed();

    IBentoBoxV1 public immutable bentoBox;
    IBerachainBex public immutable bex;
    address public immutable mim;
    address public immutable pool;
    address public immutable lp;
    address public immutable zeroXExchangeProxy;

    constructor(IBentoBoxV1 _bentoBox, IBerachainBex _bex, address _pool, address _lp, address _mim, address _zeroXExchangeProxy) {
        bentoBox = _bentoBox;
        bex = _bex;
        pool = _pool;
        lp = _lp;
        mim = _mim;
        zeroXExchangeProxy = _zeroXExchangeProxy;

        if (_zeroXExchangeProxy != address(0)) {
            _mim.safeApprove(_zeroXExchangeProxy, type(uint256).max);
        }

        mim.safeApprove(address(_bentoBox), type(uint256).max);
        lp.safeApprove(address(_bex), type(uint256).max);
    }

    /// @inheritdoc ISwapperV2
    function swap(
        address,
        address,
        address recipient,
        uint256 shareToMin,
        uint256 shareFrom,
        bytes calldata data
    ) public override returns (uint256 extraShare, uint256 shareReturned) {
        (address underlyingToken, uint8 poolIndex, bytes memory swapData) = abi.decode(data, (address, uint8, bytes));

        bentoBox.withdraw(IERC20(lp), address(this), address(this), 0, shareFrom);

        (, uint256[] memory amounts) = bex.getRemoveLiquidityOneSideOut(
            pool,
            underlyingToken,
            lp.balanceOf(address(this))
        );

        bex.removeLiquidityExactAmount(pool, address(this), underlyingToken, amounts[poolIndex], lp, lp.balanceOf(address(this)));

        // optional underlying -> MIM
        if (swapData.length > 0) {
            (bool success, ) = zeroXExchangeProxy.call(swapData);
            if (!success) {
                revert ErrSwapFailed();
            }
        }

        // Refund remaining mim and underlyingToken balances to the recipient
        uint256 balance = mim.balanceOf(address(this));
        if (balance > 0) {
            mim.safeTransfer(recipient, balance);
        }
        balance = underlyingToken.balanceOf(address(this));
        if (balance > 0) {
            underlyingToken.safeTransfer(recipient, balance);
        }

        (, shareReturned) = bentoBox.deposit(IERC20(mim), address(this), recipient, mim.balanceOf(address(this)), 0);
        extraShare = shareReturned - shareToMin;
    }
}
