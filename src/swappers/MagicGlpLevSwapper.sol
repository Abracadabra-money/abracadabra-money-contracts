// SPDX-License-Identifier: MIT
// solhint-disable avoid-low-level-calls
pragma solidity >=0.8.0;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {IBentoBoxLite} from "/interfaces/IBentoBoxV1.sol";
import {ILevSwapperV2} from "/interfaces/ILevSwapperV2.sol";
import {IERC4626} from "/interfaces/IERC4626.sol";
import {IGmxGlpRewardRouter, IGmxVault} from "/interfaces/IGmxV1.sol";

contract MagicGlpLevSwapper is ILevSwapperV2 {
    using SafeTransferLib for address;

    error ErrSwapFailed();
    error ErrTokenNotSupported();

    IBentoBoxLite public immutable box;
    address public immutable mim;
    address public immutable magicGLP;
    IGmxGlpRewardRouter public immutable glpRewardRouter;
    address public immutable sGLP;
    IGmxVault public immutable gmxVault;

    constructor(
        IBentoBoxLite _box,
        IGmxVault _gmxVault,
        address _magicGLP,
        address _mim,
        address _sGLP,
        address glpManager,
        IGmxGlpRewardRouter _glpRewardRouter
    ) {
        box = _box;
        gmxVault = _gmxVault;
        magicGLP = _magicGLP;
        mim = _mim;
        sGLP = _sGLP;
        glpRewardRouter = _glpRewardRouter;

        uint256 len = _gmxVault.allWhitelistedTokensLength();
        for (uint256 i = 0; i < len; i++) {
            address token = _gmxVault.allWhitelistedTokens(i);
            if (token == mim) continue;
            token.safeApprove(glpManager, type(uint256).max);
        }

        _sGLP.safeApprove(address(_magicGLP), type(uint256).max);
    }

    /// @inheritdoc ILevSwapperV2
    function swap(
        address recipient,
        uint256 shareToMin,
        uint256 shareFrom,
        bytes calldata data
    ) external override returns (uint256 extraShare, uint256 shareReturned) {
        (address token, address to, bytes memory swapData) = abi.decode(data, (address, address, bytes));

        box.withdraw(mim, address(this), address(this), 0, shareFrom);

        if (IERC20Metadata(mim).allowance(address(this), to) != type(uint256).max) {
            mim.safeApprove(to, type(uint256).max);
        }
        
        // MIM -> Token
        (bool success, ) = to.call(swapData);
        if (!success) {
            revert ErrSwapFailed();
        }

        uint256 _amount = token.balanceOf(address(this));

        _amount = glpRewardRouter.mintAndStakeGlp(address(token), _amount, 0, 0);
        _amount = IERC4626(address(magicGLP)).deposit(_amount, address(box));

        (, shareReturned) = box.deposit(magicGLP, address(box), recipient, _amount, 0);

        extraShare = shareReturned - shareToMin;
    }
}
