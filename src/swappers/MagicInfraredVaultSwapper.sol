// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {IBentoBoxLite} from "/interfaces/IBentoBoxV1.sol";
import {ISwapperV2} from "/interfaces/ISwapperV2.sol";
import {IERC4626} from "/interfaces/IERC4626.sol";
import {IKodiakVaultV1, IKodiakV1RouterStaking} from "/interfaces/IKodiak.sol";
import {IMagicInfraredVault} from "/interfaces/IMagicInfraredVault.sol";

contract MagicInfraredVaultSwapper is ISwapperV2 {
    using SafeTransferLib for address;

    error ErrSwapFailed();
    error ErrNotAllowed();

    IBentoBoxLite public immutable box;
    IERC4626 public immutable vault;
    address public immutable mim;
    address public immutable token0;
    address public immutable token1;
    address public immutable lpToken;
    IKodiakV1RouterStaking public immutable router;

    receive() external payable {
        revert ErrNotAllowed();
    }

    constructor(IBentoBoxLite _box, IERC4626 _vault, address _mim, IKodiakV1RouterStaking _router) {
        box = _box;
        vault = _vault;
        mim = _mim;
        router = _router;
        
        lpToken = vault.asset();
        token0 = IKodiakVaultV1(lpToken).token0();
        token1 = IKodiakVaultV1(lpToken).token1();
        
        mim.safeApprove(address(_box), type(uint256).max);
        lpToken.safeApprove(address(router), type(uint256).max);
    }

    function swap(
        address,
        address,
        address recipient,
        uint256 shareToMin,
        uint256 shareFrom,
        bytes calldata data
    ) public override returns (uint256 extraShare, uint256 shareReturned) {
        (address[] memory to, bytes[] memory swapData) = abi.decode(data, (address[], bytes[]));
        (uint256 amount, ) = box.withdraw(address(vault), address(this), address(this), 0, shareFrom);

        // ERC4626 -> LP Token
        amount = IERC4626(address(vault)).redeem(amount, address(this), address(this));

        // Remove liquidity from Kodiak
        router.removeLiquidity(
            IKodiakVaultV1(lpToken),
            amount,
            0, // min amount 0
            0, // min amount 1
            address(this)
        );

        // Token0 -> MIM
        {
            if (IERC20Metadata(token0).allowance(address(this), to[0]) != type(uint256).max) {
                token0.safeApprove(to[0], type(uint256).max);
            }

            Address.functionCall(to[0], swapData[0]);

            // Refund remaining balances to the recipient
            uint256 balance = token0.balanceOf(address(this));
            if (balance > 0) {
                token0.safeTransfer(recipient, balance);
            }
        }

        // Token1 -> MIM
        {
            if (IERC20Metadata(token1).allowance(address(this), to[1]) != type(uint256).max) {
                token1.safeApprove(to[1], type(uint256).max);
            }

            Address.functionCall(to[1], swapData[1]);

            uint256 balance = token1.balanceOf(address(this));
            if (balance > 0) {
                token1.safeTransfer(recipient, balance);
            }
        }

        (, shareReturned) = box.deposit(mim, address(this), recipient, mim.balanceOf(address(this)), 0);
        extraShare = shareReturned - shareToMin;
    }
} 