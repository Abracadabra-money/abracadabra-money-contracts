// SPDX-License-Identifier: MIT
// solhint-disable avoid-low-level-calls
pragma solidity >=0.8.0;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {IBentoBoxLite} from "/interfaces/IBentoBoxV1.sol";
import {ISwapperV2} from "/interfaces/ISwapperV2.sol";
import {IKodiakV1RouterStaking, IKodiakVaultV1} from "/interfaces/IKodiak.sol";
import {IERC4626} from "/interfaces/IERC4626.sol";

struct SwapInfo {
    address to;
    bytes swapData;
}

contract MagicKodiakIslandSwapper is ISwapperV2 {
    using SafeTransferLib for address;

    IBentoBoxLite public immutable box;
    address public immutable mim;
    IKodiakVaultV1 public immutable kodiakVault;
    IERC4626 public immutable magicKodiakVault;
    address public immutable token0;
    address public immutable token1;
    IKodiakV1RouterStaking public immutable kodiakRouter;

    constructor(IBentoBoxLite _box, address _magicKodiakVault, address _mim, IKodiakV1RouterStaking _kodiakRouter) {
        box = _box;
        mim = _mim;
        kodiakVault = IKodiakVaultV1(IERC4626(_magicKodiakVault).asset());
        magicKodiakVault = IERC4626(_magicKodiakVault);
        token0 = kodiakVault.token0();
        token1 = kodiakVault.token1();
        kodiakRouter = _kodiakRouter;
        _mim.safeApprove(address(_box), type(uint256).max);
        address(kodiakVault).safeApprove(address(_kodiakRouter), type(uint256).max);
    }

    function swap(
        address,
        address,
        address recipient,
        uint256 shareToMin,
        uint256 shareFrom,
        bytes calldata data
    ) external override returns (uint256 extraShare, uint256 shareReturned) {
        (SwapInfo memory swapInfo0, SwapInfo memory swapInfo1) = abi.decode(data, (SwapInfo, SwapInfo));

        (uint256 amount, ) = box.withdraw(address(magicKodiakVault), address(this), address(this), 0, shareFrom);
        amount = magicKodiakVault.redeem(amount, address(this), address(this));

        kodiakRouter.removeLiquidity(kodiakVault, amount, 0, 0, address(this));

        // token0 -> MIM
        if (swapInfo0.to != address(0)) {
            if (IERC20Metadata(token0).allowance(address(this), swapInfo0.to) != type(uint256).max) {
                token0.safeApprove(swapInfo0.to, type(uint256).max);
            }

            Address.functionCall(swapInfo0.to, swapInfo0.swapData);

            // Refund remaining token0 balance to the recipient
            amount = token0.balanceOf(address(this));
            if (amount > 0) {
                token0.safeTransfer(recipient, amount);
            }
        }

        // token1 -> MIM
        if (swapInfo1.to != address(0)) {
            if (IERC20Metadata(token1).allowance(address(this), swapInfo1.to) != type(uint256).max) {
                token1.safeApprove(swapInfo1.to, type(uint256).max);
            }

            Address.functionCall(swapInfo1.to, swapInfo1.swapData);

            // Refund remaining token1 balance to the recipient
            amount = token1.balanceOf(address(this));
            if (amount > 0) {
                token1.safeTransfer(recipient, amount);
            }
        }

        (, shareReturned) = box.deposit(mim, address(this), recipient, mim.balanceOf(address(this)), 0);
        extraShare = shareReturned - shareToMin;
    }
}
