// SPDX-License-Identifier: MIT
// solhint-disable avoid-low-level-calls
pragma solidity >=0.8.0;

import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {BoringERC20} from "BoringSolidity/libraries/BoringERC20.sol";
import {SafeApproveLib} from "libraries/SafeApproveLib.sol";
import {IBentoBoxV1} from "interfaces/IBentoBoxV1.sol";
import {ILevSwapperV2} from "interfaces/ILevSwapperV2.sol";
import {IERC4626} from "interfaces/IERC4626.sol";
import {IGmxGlpRewardRouter, IGmxVault} from "interfaces/IGmxV1.sol";

contract ERC4626LevSwapper is ILevSwapperV2 {
    using BoringERC20 for IERC20;
    using SafeApproveLib for IERC20;

    error ErrSwapFailed();

    IBentoBoxV1 public immutable bentoBox;
    IERC20 public immutable mim;
    IERC20 public immutable token;
    IERC4626 public immutable vault;
    address public immutable zeroXExchangeProxy;

    constructor(IBentoBoxV1 _bentoBox, IERC4626 _vault, IERC20 _mim, address _zeroXExchangeProxy) {
        bentoBox = _bentoBox;
        vault = _vault;
        mim = _mim;
        zeroXExchangeProxy = _zeroXExchangeProxy;

        IERC20 _token = _vault.asset();
        token = _token;

        _token.approve(address(_vault), type(uint256).max);
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

        // MIM -> Asset
        (bool success, ) = zeroXExchangeProxy.call(swapData);
        if (!success) {
            revert ErrSwapFailed();
        }

        uint256 _amount = token.balanceOf(address(this));
        _amount = vault.deposit(_amount, address(bentoBox));

        (, shareReturned) = bentoBox.deposit(IERC20(address(vault)), address(bentoBox), recipient, _amount, 0);

        extraShare = shareReturned - shareToMin;
    }
}
