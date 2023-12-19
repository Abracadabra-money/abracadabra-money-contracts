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

contract MagicGlpSwapper is ISwapperV2 {
    using BoringERC20 for IERC20;
    using SafeApproveLib for IERC20;

    error ErrSwapFailed();
    error ErrTokenNotSupported(IERC20);

    IBentoBoxV1 public immutable bentoBox;
    IERC20 public immutable magicGlp;
    IERC20 public immutable mim;
    IERC20 public immutable sGLP;
    IGmxGlpRewardRouter public immutable glpRewardRouter;
    address public immutable zeroXExchangeProxy;
    IGmxVault public immutable gmxVault;

    constructor(
        IBentoBoxV1 _bentoBox,
        IGmxVault _gmxVault,
        IERC20 _magicGlp,
        IERC20 _mim,
        IERC20 _sGLP,
        IGmxGlpRewardRouter _glpRewardRouter,
        address _zeroXExchangeProxy
    ) {
        bentoBox = _bentoBox;
        gmxVault = _gmxVault;
        magicGlp = _magicGlp;
        mim = _mim;
        sGLP = _sGLP;
        glpRewardRouter = _glpRewardRouter;
        zeroXExchangeProxy = _zeroXExchangeProxy;

        uint256 len = _gmxVault.allWhitelistedTokensLength();
        for (uint256 i = 0; i < len; i++) {
            IERC20 token = IERC20(_gmxVault.allWhitelistedTokens(i));
            if (token == mim) continue;
            token.safeApprove(_zeroXExchangeProxy, type(uint256).max);
        }

        mim.approve(address(_bentoBox), type(uint256).max);
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
        (bytes memory swapData, IERC20 token) = abi.decode(data, (bytes, IERC20));

        (uint256 amount, ) = bentoBox.withdraw(IERC20(address(magicGlp)), address(this), address(this), 0, shareFrom);
        amount = IERC4626(address(magicGlp)).redeem(amount, address(this), address(this));

        glpRewardRouter.unstakeAndRedeemGlp(address(token), amount, 0, address(this));

        // Token -> MIM
        (bool success, ) = zeroXExchangeProxy.call(swapData);
        if (!success) {
            revert ErrSwapFailed();
        }

        // we can expect dust from both gmx and 0x
        token.safeTransfer(recipient, token.balanceOf(address(this)));

        (, shareReturned) = bentoBox.deposit(mim, address(this), recipient, mim.balanceOf(address(this)), 0);
        extraShare = shareReturned - shareToMin;
    }
}
