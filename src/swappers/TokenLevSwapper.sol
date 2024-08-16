// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {IBentoBoxLite} from "/interfaces/IBentoBoxV1.sol";
import {ILevSwapperV2} from "/interfaces/ILevSwapperV2.sol";

contract TokenLevSwapper is ILevSwapperV2 {
    using SafeTransferLib for address;
    error ErrSwapFailed();

    IBentoBoxLite public immutable box;
    address public immutable mim;
    address public immutable token;

    constructor(IBentoBoxLite _box, address _token, address _mim) {
        box = _box;
        token = _token;
        mim = _mim;
        _token.safeApprove(address(_box), type(uint256).max);
    }

    function swap(
        address recipient,
        uint256 shareToMin,
        uint256 shareFrom,
        bytes calldata data
    ) external override returns (uint256 extraShare, uint256 shareReturned) {
        (address to, bytes memory swapData) = abi.decode(data, (address, bytes));
        box.withdraw(mim, address(this), address(this), 0, shareFrom);

        if (IERC20(mim).allowance(address(this), to) != type(uint256).max) {
            mim.safeApprove(to, type(uint256).max);
        }

        // MIM -> token
        (bool success, ) = to.call(swapData);
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
