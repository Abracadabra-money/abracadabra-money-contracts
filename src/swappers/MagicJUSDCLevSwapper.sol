// SPDX-License-Identifier: MIT
// solhint-disable avoid-low-level-calls
pragma solidity >=0.8.0;

import {IERC20} from "@BoringSolidity/interfaces/IERC20.sol";
import {BoringERC20} from "@BoringSolidity/libraries/BoringERC20.sol";
import {SafeApproveLib} from "/libraries/SafeApproveLib.sol";
import {IBentoBoxV1} from "/interfaces/IBentoBoxV1.sol";
import {ILevSwapperV2} from "/interfaces/ILevSwapperV2.sol";
import {IERC4626} from "/interfaces/IERC4626.sol";
import {IGmxGlpRewardRouter, IGmxVault} from "/interfaces/IGmxV1.sol";
import {IJonesRouter} from "/interfaces/IJonesRouter.sol";

contract MagicJUSDCLevSwapper is ILevSwapperV2 {
    using BoringERC20 for IERC20;
    using SafeApproveLib for IERC20;

    error ErrSwapFailed();

    IBentoBoxV1 public immutable bentoBox;
    IERC20 public immutable mim;
    IERC20 public immutable usdc;
    IERC20 public immutable jusdc;
    IERC4626 public immutable magicJUSDC;
    address public immutable zeroXExchangeProxy;
    IJonesRouter public immutable jonesRouter;

    constructor(IBentoBoxV1 _bentoBox, IERC4626 _magicJUSDC, IERC20 _mim, IJonesRouter _jonesRouter, address _zeroXExchangeProxy) {
        bentoBox = _bentoBox;
        magicJUSDC = _magicJUSDC;
        mim = _mim;
        zeroXExchangeProxy = _zeroXExchangeProxy;
        jonesRouter = _jonesRouter;

        IERC20 _jusdc = _magicJUSDC.asset();
        usdc = IERC4626(address(_jusdc)).asset();
        jusdc = _jusdc;

        _jusdc.approve(address(_magicJUSDC), type(uint256).max);
        usdc.approve(address(_jonesRouter), type(uint256).max);
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

        uint256 _amount = jonesRouter.deposit(usdc.balanceOf(address(this)), address(this));
        _amount = magicJUSDC.deposit(_amount, address(bentoBox));

        // Refund remaining mim balance to the recipient
        uint256 balance = mim.balanceOf(address(this));
        if (balance > 0) {
            mim.safeTransfer(recipient, balance);
        }

        (, shareReturned) = bentoBox.deposit(IERC20(address(magicJUSDC)), address(bentoBox), recipient, _amount, 0);

        extraShare = shareReturned - shareToMin;
    }
}
