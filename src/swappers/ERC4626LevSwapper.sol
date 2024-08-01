// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {IBentoBoxLight} from "/interfaces/IBentoBoxV1.sol";
import {ILevSwapperV2} from "/interfaces/ILevSwapperV2.sol";
import {IERC4626} from "/interfaces/IERC4626.sol";

contract ERC4626LevSwapper is ILevSwapperV2 {
    using SafeTransferLib for address;
    error ErrSwapFailed();

    IBentoBoxLight public immutable box;
    address public immutable mim;
    address public immutable token;
    IERC4626 public immutable vault;
    address public immutable zeroXExchangeProxy;

    constructor(IBentoBoxLight _box, IERC4626 _vault, address _mim, address _zeroXExchangeProxy) {
        box = _box;
        vault = _vault;
        mim = _mim;
        zeroXExchangeProxy = _zeroXExchangeProxy;

        address _token = _vault.asset();
        token = _token;

        _token.safeApprove(address(_vault), type(uint256).max);
        _mim.safeApprove(_zeroXExchangeProxy, type(uint256).max);
    }

    function swap(
        address recipient,
        uint256 shareToMin,
        uint256 shareFrom,
        bytes calldata swapData
    ) external override returns (uint256 extraShare, uint256 shareReturned) {
        box.withdraw(mim, address(this), address(this), 0, shareFrom);

        // MIM -> Asset
        (bool success, ) = zeroXExchangeProxy.call(swapData);
        if (!success) {
            revert ErrSwapFailed();
        }

        uint256 _amount = token.balanceOf(address(this));
        _amount = vault.deposit(_amount, address(box));

        // Refund remaining mim balance to the recipient
        uint256 balance = mim.balanceOf(address(this));
        if (balance > 0) {
            mim.safeTransfer(recipient, balance);
        }

        (, shareReturned) = box.deposit(address(vault), address(box), recipient, _amount, 0);

        extraShare = shareReturned - shareToMin;
    }
}
