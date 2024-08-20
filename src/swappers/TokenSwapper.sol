// SPDX-License-Identifier: MIT
// solhint-disable avoid-low-level-calls
pragma solidity >=0.8.0;

import {IERC20} from "@BoringSolidity/interfaces/IERC20.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {IBentoBoxLite} from "/interfaces/IBentoBoxV1.sol";
import {ISwapperV2} from "/interfaces/ISwapperV2.sol";

/// @notice token liquidation/deleverage swapper for tokens using Matcha/0x aggregator
contract TokenSwapper is ISwapperV2 {
    using SafeTransferLib for address;

    error ErrSwapFailed();

    IBentoBoxLite public immutable box;
    address public immutable token;
    address public immutable mim;

    constructor(IBentoBoxLite _box, address _token, address _mim) {
        box = _box;
        token = _token;
        mim = _mim;
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
        box.withdraw(token, address(this), address(this), 0, shareFrom);

        if (IERC20(token).allowance(address(this), to) != type(uint256).max) {
            token.safeApprove(to, type(uint256).max);
        }

        // token -> MIM
        (bool success, ) = to.call(swapData);
        if (!success) {
            revert ErrSwapFailed();
        }

        // Refund remaining balance to the recipient
        uint256 balance = token.balanceOf(address(this));
        if (balance > 0) {
            token.safeTransfer(recipient, balance);
        }

        (, shareReturned) = box.deposit(mim, address(this), recipient, mim.balanceOf(address(this)), 0);
        extraShare = shareReturned - shareToMin;
    }
}
