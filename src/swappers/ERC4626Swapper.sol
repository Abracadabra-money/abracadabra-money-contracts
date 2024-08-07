// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {IBentoBoxLite} from "/interfaces/IBentoBoxV1.sol";
import {ISwapperV2} from "/interfaces/ISwapperV2.sol";
import {IERC4626} from "/interfaces/IERC4626.sol";

contract ERC4626Swapper is ISwapperV2 {
    using SafeTransferLib for address;
    error ErrSwapFailed();
    error ErrTokenNotSupported(address);

    IBentoBoxLite public immutable box;
    IERC4626 public immutable vault;
    address public immutable mim;
    address public immutable asset;
    address public immutable zeroXExchangeProxy;

    constructor(IBentoBoxLite _box, IERC4626 _vault, address _mim, address _zeroXExchangeProxy) {
        box = _box;
        vault = _vault;
        mim = _mim;
        zeroXExchangeProxy = _zeroXExchangeProxy;

        address _asset = _vault.asset();
        asset = _asset;

        _asset.safeApprove(_zeroXExchangeProxy, type(uint256).max);
        mim.safeApprove(address(_box), type(uint256).max);
    }

    function swap(
        address,
        address,
        address recipient,
        uint256 shareToMin,
        uint256 shareFrom,
        bytes calldata swapData
    ) public override returns (uint256 extraShare, uint256 shareReturned) {
        (uint256 amount, ) = box.withdraw(address(vault), address(this), address(this), 0, shareFrom);
        amount = IERC4626(address(vault)).redeem(amount, address(this), address(this));

        // Asset -> MIM
        (bool success, ) = zeroXExchangeProxy.call(swapData);
        if (!success) {
            revert ErrSwapFailed();
        }

        // Refund remaining balance to the recipient
        uint256 balance = asset.balanceOf(address(this));
        if (balance > 0) {
            asset.safeTransfer(recipient, balance);
        }

        (, shareReturned) = box.deposit(mim, address(this), recipient, mim.balanceOf(address(this)), 0);
        extraShare = shareReturned - shareToMin;
    }
}
