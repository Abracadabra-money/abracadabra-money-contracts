// SPDX-License-Identifier: MIT
// solhint-disable avoid-low-level-calls
pragma solidity >=0.8.0;

import "BoringSolidity/interfaces/IERC20.sol";
import "BoringSolidity/libraries/BoringERC20.sol";
import "libraries/SafeApprove.sol";
import "interfaces/IBentoBoxV1.sol";
import "interfaces/ILevSwapperV2.sol";
import "interfaces/IERC4626.sol";
import "interfaces/IGmxGlpRewardRouter.sol";
import "interfaces/IGmxVault.sol";

contract MagicApeLevSwapper is ILevSwapperV2 {
    using BoringERC20 for IERC20;
    using SafeApprove for IERC20;

    error ErrSwapFailed();

    IBentoBoxV1 public immutable bentoBox;
    IERC20 public immutable mim;
    IERC20 public immutable ape;
    IERC4626 public immutable magicApe;
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

        _ape.approve(address(_magicApe), type(uint256).max);
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

        // MIM -> Ape
        (bool success, ) = zeroXExchangeProxy.call(swapData);
        if (!success) {
            revert ErrSwapFailed();
        }

        uint256 _amount = ape.balanceOf(address(this));
        _amount = magicApe.deposit(_amount, address(bentoBox));

        (, shareReturned) = bentoBox.deposit(IERC20(address(magicApe)), address(bentoBox), recipient, _amount, 0);

        extraShare = shareReturned - shareToMin;
    }
}
