// SPDX-License-Identifier: MIT
// solhint-disable avoid-low-level-calls
pragma solidity >=0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {IBentoBoxLite} from "/interfaces/IBentoBoxV1.sol";
import {ILevSwapperV2} from "/interfaces/ILevSwapperV2.sol";
import {IYearnVault} from "/interfaces/IYearnVault.sol";

contract YearnLevSwapper is ILevSwapperV2 {
    using SafeTransferLib for address;

    error ErrSwapFailed();

    IBentoBoxLite public immutable box;
    IYearnVault public immutable vault;
    address public immutable mim;
    address public immutable underlyingToken;

    constructor(IBentoBoxLite _box, IYearnVault _vault, address _mim) {
        box = _box;
        underlyingToken = _vault.token();
        vault = _vault;
        mim = _mim;
        underlyingToken.safeApprove(address(_vault), type(uint256).max);
    }

    /// @inheritdoc ILevSwapperV2
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

        // MIM -> underlyingToken
        (bool success, ) = to.call(swapData);
        if (!success) {
            revert ErrSwapFailed();
        }

        // Refund remaining mim balance to the recipient
        uint256 balance = mim.balanceOf(address(this));
        if (balance > 0) {
            mim.safeTransfer(recipient, balance);
        }

        uint256 amount = vault.deposit(underlyingToken.balanceOf(address(this)), address(box));

        (, shareReturned) = box.deposit(address(vault), address(box), recipient, amount, 0);
        extraShare = shareReturned - shareToMin;
    }
}
