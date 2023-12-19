// SPDX-License-Identifier: MIT
// solhint-disable avoid-low-level-calls
pragma solidity >=0.8.0;

import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {BoringERC20} from "BoringSolidity/libraries/BoringERC20.sol";
import {SafeApproveLib} from "libraries/SafeApproveLib.sol";
import {IBentoBoxV1} from "interfaces/IBentoBoxV1.sol";
import {ISwapperV2} from "interfaces/ISwapperV2.sol";
import {IGmxGlpRewardRouter, IGmxVault} from "interfaces/IGmxV1.sol";
import {IERC4626} from "interfaces/IERC4626.sol";

contract ERC4626Swapper is ISwapperV2 {
    using BoringERC20 for IERC20;
    using SafeApproveLib for IERC20;

    error ErrSwapFailed();
    error ErrTokenNotSupported(IERC20);

    IBentoBoxV1 public immutable bentoBox;
    IERC4626 public immutable vault;
    IERC20 public immutable mim;
    IERC20 public immutable asset;
    address public immutable zeroXExchangeProxy;

    constructor(IBentoBoxV1 _bentoBox, IERC4626 _vault, IERC20 _mim, address _zeroXExchangeProxy) {
        bentoBox = _bentoBox;
        vault = _vault;
        mim = _mim;
        zeroXExchangeProxy = _zeroXExchangeProxy;

        IERC20 _asset = _vault.asset();
        asset = _asset;

        _asset.safeApprove(_zeroXExchangeProxy, type(uint256).max);
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
        (uint256 amount, ) = bentoBox.withdraw(IERC20(address(vault)), address(this), address(this), 0, shareFrom);
        amount = IERC4626(address(vault)).redeem(amount, address(this), address(this));

        // Asset -> MIM
        (bool success, ) = zeroXExchangeProxy.call(swapData);
        if (!success) {
            revert ErrSwapFailed();
        }

        (, shareReturned) = bentoBox.deposit(mim, address(this), recipient, mim.balanceOf(address(this)), 0);
        extraShare = shareReturned - shareToMin;
    }
}
