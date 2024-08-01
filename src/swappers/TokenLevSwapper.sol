// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {IBentoBoxLight} from "/interfaces/IBentoBoxV1.sol";
import {ILevSwapperV2} from "/interfaces/ILevSwapperV2.sol";

contract TokenLevSwapper is ILevSwapperV2 {
    using SafeTransferLib for address;
    error ErrSwapFailed();

    IBentoBoxLight public immutable box;
    address public immutable mim;
    address public immutable token;
    address public immutable zeroXExchangeProxy;

    constructor(IBentoBoxLight _box, address _token, address _mim, address _zeroXExchangeProxy) {
        box = _box;
        token = _token;
        mim = _mim;
        zeroXExchangeProxy = _zeroXExchangeProxy;
        _token.safeApprove(address(_box), type(uint256).max);
        _mim.safeApprove(_zeroXExchangeProxy, type(uint256).max);
    }

    /// @inheritdoc ILevSwapperV2
    function swap(
        address recipient,
        uint256 shareToMin,
        uint256 shareFrom,
        bytes calldata swapData
    ) external override returns (uint256 extraShare, uint256 shareReturned) {
        box.withdraw(mim, address(this), address(this), 0, shareFrom);

        // MIM -> token
        (bool success, ) = zeroXExchangeProxy.call(swapData);
        if (!success) {
            revert ErrSwapFailed();
        }

        // Refund remaining mim balance to the recipient
        uint256 balance = mim.balanceOf(address(this));
        if (balance > 0) {
            mim.safeTransfer(recipient, balance);
        }

        (, shareReturned) = box.deposit(token, address(this), recipient, token.balanceOf(address(this)), 0);
        extraShare = shareReturned - shareToMin;
    }
}
