// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {IBentoBoxLite} from "/interfaces/IBentoBoxV1.sol";
import {ILevSwapperV2} from "/interfaces/ILevSwapperV2.sol";
import {IERC4626} from "/interfaces/IERC4626.sol";
import {IKodiakVaultV1, IKodiakV1RouterStaking} from "/interfaces/IKodiak.sol";
import {IMagicInfraredVault} from "/interfaces/IMagicInfraredVault.sol";

contract MagicInfraredVaultLevSwapper is ILevSwapperV2 {
    using SafeTransferLib for address;

    error ErrSwapFailed();

    IBentoBoxLite public immutable box;
    IERC4626 public immutable vault;
    address public immutable mim;
    address public immutable token0;
    address public immutable token1;
    address public immutable lpToken;
    IKodiakV1RouterStaking public immutable router;

    constructor(IBentoBoxLite _box, IERC4626 _vault, address _mim, IKodiakV1RouterStaking _router) {
        box = _box;
        vault = _vault;
        mim = _mim;
        router = _router;
        
        lpToken = vault.asset();
        token0 = IKodiakVaultV1(lpToken).token0();
        token1 = IKodiakVaultV1(lpToken).token1();
        
        token0.safeApprove(address(router), type(uint256).max);
        token1.safeApprove(address(router), type(uint256).max);
        lpToken.safeApprove(address(vault), type(uint256).max);
    }

    function swap(
        address recipient,
        uint256 shareToMin,
        uint256 shareFrom,
        bytes calldata data
    ) external override returns (uint256 extraShare, uint256 shareReturned) {
        (address[] memory to, bytes[] memory swapData) = abi.decode(data, (address[], bytes[]));
        box.withdraw(mim, address(this), address(this), 0, shareFrom);

        _swapTokens(to, swapData);
        uint256 _lpAmount = _addLiquidity();
        uint256 _amount = _depositToVault(_lpAmount);
        
        _refundRemainingTokens(recipient);

        (, shareReturned) = box.deposit(address(vault), address(box), recipient, _amount, 0);
        extraShare = shareReturned - shareToMin;
    }
    
    function _swapTokens(address[] memory to, bytes[] memory swapData) internal {
        // MIM -> Token0
        if (IERC20Metadata(mim).allowance(address(this), to[0]) != type(uint256).max) {
            mim.safeApprove(to[0], type(uint256).max);
        }
        Address.functionCall(to[0], swapData[0]);

        // MIM -> Token1
        if (IERC20Metadata(mim).allowance(address(this), to[1]) != type(uint256).max) {
            mim.safeApprove(to[1], type(uint256).max);
        }
        Address.functionCall(to[1], swapData[1]);
    }
    
    function _addLiquidity() internal returns (uint256) {
        uint256 amount0 = token0.balanceOf(address(this));
        uint256 amount1 = token1.balanceOf(address(this));

        // Add liquidity to Kodiak
        router.addLiquidity(
            IKodiakVaultV1(lpToken),
            amount0,
            amount1,
            0, // min amount 0
            0, // min amount 1
            0, // min LP
            address(this)
        );

        return lpToken.balanceOf(address(this));
    }
    
    function _depositToVault(uint256 lpAmount) internal returns (uint256) {
        // Deposit to the vault, which will stake in Infrared
        return vault.deposit(lpAmount, address(box));
    }
    
    function _refundRemainingTokens(address recipient) internal {
        // Refund remaining mim balance to the recipient
        uint256 balance = mim.balanceOf(address(this));
        if (balance > 0) {
            mim.safeTransfer(recipient, balance);
        }

        // Refund remaining tokens to the recipient
        balance = token0.balanceOf(address(this));
        if (balance > 0) {
            token0.safeTransfer(recipient, balance);
        }
        
        balance = token1.balanceOf(address(this));
        if (balance > 0) {
            token1.safeTransfer(recipient, balance);
        }
    }
}