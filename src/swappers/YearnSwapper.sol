// SPDX-License-Identifier: MIT
// solhint-disable avoid-low-level-calls
pragma solidity >=0.8.0;

import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IBentoBoxLite} from "/interfaces/IBentoBoxV1.sol";
import {ISwapperV2} from "/interfaces/ISwapperV2.sol";
import {IYearnVault} from "/interfaces/IYearnVault.sol";

contract YearnSwapper is ISwapperV2 {
    using SafeTransferLib for address;

    error ErrSwapFailed();

    IBentoBoxLite public immutable bentoBox;
    IYearnVault public immutable wrapper;
    address public immutable underlyingToken;
    address public immutable mim;

    constructor(IBentoBoxLite _bentoBox, IYearnVault _wrapper, address _mim) {
        bentoBox = _bentoBox;
        underlyingToken = _wrapper.token();
        wrapper = _wrapper;
        mim = _mim;
        mim.safeApprove(address(_bentoBox), type(uint256).max);
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
        (address to, bytes memory swapData) = abi.decode(data, (address, bytes));
        (uint amount, ) = bentoBox.withdraw(address(wrapper), address(this), address(this), 0, shareFrom);

        amount = wrapper.withdraw(amount, address(this));

        if (IERC20(underlyingToken).allowance(address(this), to) != type(uint256).max) {
            underlyingToken.safeApprove(to, type(uint256).max);
        }

        // underlyingToken -> MIM
        (bool success, ) = to.call(swapData);
        if (!success) {
            revert ErrSwapFailed();
        }

        // Refund remaining balance to the recipient
        uint256 balance = underlyingToken.balanceOf(address(this));
        if (balance > 0) {
            underlyingToken.safeTransfer(recipient, balance);
        }

        (, shareReturned) = bentoBox.deposit(mim, address(this), recipient, mim.balanceOf(address(this)), 0);
        extraShare = shareReturned - shareToMin;
    }
}
