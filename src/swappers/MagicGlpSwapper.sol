// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {IBentoBoxLite} from "/interfaces/IBentoBoxV1.sol";
import {ISwapperV2} from "/interfaces/ISwapperV2.sol";
import {IGmxGlpRewardRouter, IGmxVault} from "/interfaces/IGmxV1.sol";
import {IERC4626} from "/interfaces/IERC4626.sol";

contract MagicGlpSwapper is ISwapperV2 {
    using SafeTransferLib for address;

    error ErrSwapFailed();
    error ErrTokenNotSupported();

    IBentoBoxLite public immutable box;
    address public immutable magicGlp;
    address public immutable mim;
    address public immutable sGLP;
    IGmxGlpRewardRouter public immutable glpRewardRouter;
    IGmxVault public immutable gmxVault;

    constructor(
        IBentoBoxLite _box,
        IGmxVault _gmxVault,
        address _magicGlp,
        address _mim,
        address _sGLP,
        IGmxGlpRewardRouter _glpRewardRouter
    ) {
        box = _box;
        gmxVault = _gmxVault;
        magicGlp = _magicGlp;
        mim = _mim;
        sGLP = _sGLP;
        glpRewardRouter = _glpRewardRouter;

        mim.safeApprove(address(_box), type(uint256).max);
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
        (address token, address to, bytes memory swapData) = abi.decode(data, (address, address, bytes));

        (uint256 amount, ) = box.withdraw(address(magicGlp), address(this), address(this), 0, shareFrom);
        amount = IERC4626(address(magicGlp)).redeem(amount, address(this), address(this));

        glpRewardRouter.unstakeAndRedeemGlp(address(token), amount, 0, address(this));

        if (IERC20Metadata(token).allowance(address(this), to) != type(uint256).max) {
            token.safeApprove(to, type(uint256).max);
        }

        // Token -> MIM
        (bool success, ) = to.call(swapData);
        if (!success) {
            revert ErrSwapFailed();
        }

        // we can expect dust from both gmx and 0x
        token.safeTransfer(recipient, token.balanceOf(address(this)));

        (, shareReturned) = box.deposit(mim, address(this), recipient, mim.balanceOf(address(this)), 0);
        extraShare = shareReturned - shareToMin;
    }
}
