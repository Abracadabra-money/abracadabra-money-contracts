// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
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

    constructor(IBentoBoxLite _box, IERC4626 _vault, address _mim) {
        box = _box;
        vault = _vault;
        mim = _mim;

        address _asset = _vault.asset();
        asset = _asset;
        mim.safeApprove(address(_box), type(uint256).max);
    }

    function swap(
        address,
        address,
        address recipient,
        uint256 shareToMin,
        uint256 shareFrom,
        bytes calldata data
    ) public override returns (uint256 extraShare, uint256 shareReturned) {
        (address to, bytes memory swapData) = abi.decode(data, (address, bytes));
        (uint256 amount, ) = box.withdraw(address(vault), address(this), address(this), 0, shareFrom);

        IERC4626(address(vault)).redeem(amount, address(this), address(this));

        if (IERC20(asset).allowance(address(this), to) != type(uint256).max) {
            asset.safeApprove(to, type(uint256).max);
        }

        (bool success, ) = to.call(swapData);
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
