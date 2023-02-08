// SPDX-License-Identifier: MIT
// solhint-disable avoid-low-level-calls
pragma solidity >=0.8.0;

import "BoringSolidity/interfaces/IERC20.sol";
import "BoringSolidity/libraries/BoringERC20.sol";
import "libraries/SafeApprove.sol";
import "interfaces/IBentoBoxV1.sol";
import "interfaces/ISwapperV2.sol";
import "interfaces/IGmxGlpRewardRouter.sol";
import "interfaces/IERC4626.sol";
import "interfaces/IGmxVault.sol";

contract MagicApeSwapper is ISwapperV2 {
    using BoringERC20 for IERC20;
    using SafeApprove for IERC20;

    error ErrSwapFailed();
    error ErrTokenNotSupported(IERC20);

    IBentoBoxV1 public immutable bentoBox;
    IERC4626 public immutable magicApe;
    IERC20 public immutable mim;
    IERC20 public immutable ape;
    address public immutable zeroXExchangeProxy;

    constructor(
        IBentoBoxV1 _bentoBox,
        IERC4626 _magicApe,
        IERC20 _mim,
        address _zeroXExchangeProxy
    ) {
        bentoBox = _bentoBox;
        magicApe = _magicApe;
        mim = _mim;
        zeroXExchangeProxy = _zeroXExchangeProxy;

        IERC20 _ape = _magicApe.asset();
        ape = _ape;

        ape.safeApprove(_zeroXExchangeProxy, type(uint256).max);
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
        (uint256 amount, ) = bentoBox.withdraw(IERC20(address(magicApe)), address(this), address(this), 0, shareFrom);
        amount = IERC4626(address(magicApe)).redeem(amount, address(this), address(this));

        // Ape -> MIM
        (bool success, ) = zeroXExchangeProxy.call(swapData);
        if (!success) {
            revert ErrSwapFailed();
        }

        (, shareReturned) = bentoBox.deposit(mim, address(this), recipient, mim.balanceOf(address(this)), 0);
        extraShare = shareReturned - shareToMin;
    }
}
