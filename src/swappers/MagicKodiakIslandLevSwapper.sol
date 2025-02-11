// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {IBentoBoxLite} from "/interfaces/IBentoBoxV1.sol";
import {ILevSwapperV2} from "/interfaces/ILevSwapperV2.sol";
import {IKodiakV1RouterStaking, IKodiakVaultV1} from "/interfaces/IKodiak.sol";
import {IERC4626} from "/interfaces/IERC4626.sol";

struct SwapInfo {
    address to;
    bytes swapData;
}

contract MagicKodiakIslandLevSwapper is ILevSwapperV2 {
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

        _magicKodiakVault.safeApprove(address(_box), type(uint256).max);
        token0.safeApprove(address(kodiakRouter), type(uint256).max);
        token1.safeApprove(address(kodiakRouter), type(uint256).max);
        address(kodiakVault).safeApprove(address(magicKodiakVault), type(uint256).max);
    }

    function swap(
        address recipient,
        uint256 shareToMin,
        uint256 shareFrom,
        bytes calldata data
    ) external override returns (uint256 extraShare, uint256 shareReturned) {
        (SwapInfo memory swapInfo0, SwapInfo memory swapInfo1) = abi.decode(data, (SwapInfo, SwapInfo));
        box.withdraw(mim, address(this), address(this), 0, shareFrom);

        if (swapInfo0.to != address(0)) {
            if (IERC20Metadata(mim).allowance(address(this), swapInfo0.to) != type(uint256).max) {
                mim.safeApprove(swapInfo0.to, type(uint256).max);
            }

            Address.functionCall(swapInfo0.to, swapInfo0.swapData); // MIM -> token0
        }

        if (swapInfo1.to != address(0)) {
            if (IERC20Metadata(mim).allowance(address(this), swapInfo1.to) != type(uint256).max) {
                mim.safeApprove(swapInfo1.to, type(uint256).max);
            }

            Address.functionCall(swapInfo1.to, swapInfo1.swapData); // MIM -> token1
        }

        kodiakRouter.addLiquidity(
            kodiakVault,
            token0.balanceOf(address(this)),
            token1.balanceOf(address(this)),
            0,
            0,
            0, // minAmountOut will be asserted by the extraShare substraction
            address(this)
        );

        // Refund remaining mim balance to the recipient
        uint256 balance = mim.balanceOf(address(this));
        if (balance > 0) {
            mim.safeTransfer(recipient, balance);
        }

        // Refund remaining token0 balance to the recipient
        if (token0 != mim) {
            balance = token0.balanceOf(address(this));
            if (balance > 0) {
                token0.safeTransfer(recipient, balance);
            }
        }

        // Refund remaining token1 balance to the recipient
        if (token1 != mim) {
            balance = token1.balanceOf(address(this));
            if (balance > 0) {
                token1.safeTransfer(recipient, balance);
            }
        }

        // KodiakIsland -> MagicKodiakIsland
        uint256 amount = address(kodiakVault).balanceOf(address(this));
        amount = magicKodiakVault.deposit(amount, address(box));

        (, shareReturned) = box.deposit(address(magicKodiakVault), address(box), recipient, amount, 0);
        extraShare = shareReturned - shareToMin;
    }
}
