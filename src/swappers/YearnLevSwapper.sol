// SPDX-License-Identifier: MIT
// solhint-disable avoid-low-level-calls
pragma solidity >=0.8.0;

import {IERC20} from "@BoringSolidity/interfaces/IERC20.sol";
import {BoringERC20} from "@BoringSolidity/libraries/BoringERC20.sol";
import {IBentoBoxV1} from "/interfaces/IBentoBoxV1.sol";
import {ILevSwapperV2} from "/interfaces/ILevSwapperV2.sol";
import {IYearnVault} from "/interfaces/IYearnVault.sol";

contract YearnLevSwapper is ILevSwapperV2 {
    using BoringERC20 for IERC20;

    error ErrSwapFailed();

    IBentoBoxV1 public immutable bentoBox;
    IYearnVault public immutable vault;
    IERC20 public immutable mim;
    IERC20 public immutable underlyingToken;
    address public immutable zeroXExchangeProxy;

    constructor(IBentoBoxV1 _bentoBox, IYearnVault _vault, IERC20 _mim, address _zeroXExchangeProxy) {
        bentoBox = _bentoBox;
        underlyingToken = IERC20(_vault.token());
        vault = _vault;
        mim = _mim;
        zeroXExchangeProxy = _zeroXExchangeProxy;
        underlyingToken.approve(address(_vault), type(uint256).max);
        _mim.approve(_zeroXExchangeProxy, type(uint256).max);
    }

    /// @inheritdoc ILevSwapperV2
    function swap(
        address recipient,
        uint256 shareToMin,
        uint256 shareFrom,
        bytes calldata swapData
    ) external override returns (uint256 extraShare, uint256 shareReturned) {
        bentoBox.withdraw(mim, address(this), address(this), 0, shareFrom);

        // MIM -> underlyingToken
        (bool success, ) = zeroXExchangeProxy.call(swapData);
        if (!success) {
            revert ErrSwapFailed();
        }

        // Refund remaining mim balance to the recipient
        uint256 balance = mim.balanceOf(address(this));
        if (balance > 0) {
            mim.safeTransfer(recipient, balance);
        }

        uint256 amount = vault.deposit(underlyingToken.balanceOf(address(this)), address(bentoBox));

        (, shareReturned) = bentoBox.deposit(vault, address(bentoBox), recipient, amount, 0);
        extraShare = shareReturned - shareToMin;
    }
}
