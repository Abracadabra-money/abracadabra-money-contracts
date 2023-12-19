// SPDX-License-Identifier: MIT
// solhint-disable avoid-low-level-calls
pragma solidity >=0.8.0;

import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {BoringERC20} from "BoringSolidity/libraries/BoringERC20.sol";
import {IBentoBoxV1} from "interfaces/IBentoBoxV1.sol";
import {ISwapperV2} from "interfaces/ISwapperV2.sol";

/// @notice token liquidation/deleverage swapper for tokens using Matcha/0x aggregator
contract TokenSwapper is ISwapperV2 {
    using BoringERC20 for IERC20;

    error ErrSwapFailed();

    IBentoBoxV1 public immutable bentoBox;
    IERC20 public immutable token;
    IERC20 public immutable mim;
    address public immutable zeroXExchangeProxy;

    constructor(IBentoBoxV1 _bentoBox, IERC20 _token, IERC20 _mim, address _zeroXExchangeProxy) {
        bentoBox = _bentoBox;
        token = _token;
        mim = _mim;
        zeroXExchangeProxy = _zeroXExchangeProxy;
        _token.approve(_zeroXExchangeProxy, type(uint256).max);
        mim.approve(address(_bentoBox), type(uint256).max);
    }

    /// @inheritdoc ISwapperV2
    function swap(
        address,
        address,
        address recipient,
        uint256 shareToMin,
        uint256 shareFrom,
        bytes calldata swapData
    ) public override returns (uint256 extraShare, uint256 shareReturned) {
        bentoBox.withdraw(IERC20(address(token)), address(this), address(this), 0, shareFrom);

        // token -> MIM
        (bool success, ) = zeroXExchangeProxy.call(swapData);
        if (!success) {
            revert ErrSwapFailed();
        }

        // Refund remaining balance to the recipient
        uint256 balance = token.balanceOf(address(this));
        if (balance > 0) {
            token.safeTransfer(recipient, balance);
        }

        (, shareReturned) = bentoBox.deposit(mim, address(this), recipient, mim.balanceOf(address(this)), 0);
        extraShare = shareReturned - shareToMin;
    }
}
