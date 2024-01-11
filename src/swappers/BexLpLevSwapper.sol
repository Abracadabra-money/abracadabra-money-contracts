// SPDX-License-Identifier: MIT
// solhint-disable avoid-low-level-calls
pragma solidity >=0.8.0;

import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IBentoBoxV1} from "interfaces/IBentoBoxV1.sol";
import {ILevSwapperV2} from "interfaces/ILevSwapperV2.sol";
import {IBerachainBex} from "interfaces/IBerachainBex.sol";

contract BexLpLevSwapper is ILevSwapperV2 {
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
        _lp.safeApprove(address(_bentoBox), type(uint256).max);

        if (_zeroXExchangeProxy != address(0)) {
            _mim.safeApprove(_zeroXExchangeProxy, type(uint256).max);
        }
    }

    /// @inheritdoc ILevSwapperV2
    function swap(
        address recipient,
        uint256 shareToMin,
        uint256 shareFrom,
        bytes calldata data
    ) external override returns (uint256 extraShare, uint256 shareReturned) {
        (address underlyingToken, uint8 poolIndex, bytes memory swapData) = abi.decode(data, (address, uint8, bytes));
        bentoBox.withdraw(IERC20(mim), address(this), address(this), 0, shareFrom);

        // optional MIM -> input token
        if (swapData.length > 0) {
            (bool success, ) = zeroXExchangeProxy.call(swapData);
            if (!success) {
                revert ErrSwapFailed();
            }
        }

        uint256[] memory shareAmounts;
        {
            address[] memory assetsIn = new address[](2);
            uint256[] memory amountsIn = new uint256[](2);
            assetsIn[poolIndex] = underlyingToken;
            amountsIn[poolIndex] = underlyingToken.balanceOf(address(this));

            (, shareAmounts, , ) = bex.addLiquidity(pool, recipient, assetsIn, amountsIn);
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

        (, shareReturned) = bentoBox.deposit(IERC20(lp), address(this), recipient, shareAmounts[0], 0);
        extraShare = shareReturned - shareToMin;
    }
}
