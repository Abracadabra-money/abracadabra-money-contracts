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

contract MagicGlpLevSwapper is ILevSwapperV2 {
    using BoringERC20 for IERC20;
    using SafeApproveLib for IERC20;

    error ErrSwapFailed();
    error ErrTokenNotSupported(IERC20);

    IBentoBoxV1 public immutable bentoBox;
    IERC20 public immutable mim;
    IERC20 public immutable magicGLP;
    IGmxGlpRewardRouter public immutable glpRewardRouter;
    IERC20 public immutable sGLP;
    address public immutable zeroXExchangeProxy;
    IGmxVault public immutable gmxVault;

    constructor(
        IBentoBoxV1 _bentoBox,
        IGmxVault _gmxVault,
        IERC20 _magicGLP,
        IERC20 _mim,
        IERC20 _sGLP,
        address glpManager,
        IGmxGlpRewardRouter _glpRewardRouter,
        address _zeroXExchangeProxy
    ) {
        bentoBox = _bentoBox;
        gmxVault = _gmxVault;
        magicGLP = _magicGLP;
        mim = _mim;
        sGLP = _sGLP;
        glpRewardRouter = _glpRewardRouter;
        zeroXExchangeProxy = _zeroXExchangeProxy;

        uint256 len = _gmxVault.allWhitelistedTokensLength();
        for (uint256 i = 0; i < len; i++) {
            IERC20 token = IERC20(_gmxVault.allWhitelistedTokens(i));
            if (token == mim) continue;
            token.safeApprove(glpManager, type(uint256).max);
        }

        _sGLP.approve(address(_magicGLP), type(uint256).max);
        _mim.approve(_zeroXExchangeProxy, type(uint256).max);
    }

    /// @inheritdoc ILevSwapperV2
    function swap(
        address recipient,
        uint256 shareToMin,
        uint256 shareFrom,
        bytes calldata data
    ) external override returns (uint256 extraShare, uint256 shareReturned) {
        (bytes memory swapData, IERC20 token) = abi.decode(data, (bytes, IERC20));

        bentoBox.withdraw(mim, address(this), address(this), 0, shareFrom);

        // MIM -> Token
        (bool success, ) = zeroXExchangeProxy.call(swapData);
        if (!success) {
            revert ErrSwapFailed();
        }

        uint256 _amount = token.balanceOf(address(this));

        _amount = glpRewardRouter.mintAndStakeGlp(address(token), _amount, 0, 0);
        _amount = IERC4626(address(magicGLP)).deposit(_amount, address(bentoBox));

        (, shareReturned) = bentoBox.deposit(magicGLP, address(bentoBox), recipient, _amount, 0);

        extraShare = shareReturned - shareToMin;
    }
}
