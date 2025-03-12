// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {IBentoBoxLite} from "/interfaces/IBentoBoxV1.sol";
import {ILevSwapperV2} from "/interfaces/ILevSwapperV2.sol";
import {IERC4626} from "/interfaces/IERC4626.sol";
import {IBexVault, JoinPoolRequest} from "/interfaces/IBexVault.sol";

contract MagicBexVaultLevSwapper is ILevSwapperV2 {
    using SafeTransferLib for address;

    error ErrSwapFailed();
    error ErrInvalidPool();

    IBexVault public constant BEX_VAULT = IBexVault(0x4Be03f781C497A489E3cB0287833452cA9B9E80B);
    uint256 public constant MAX_TOKENS = 2;

    IBentoBoxLite public immutable box;
    IERC4626 public immutable vault;
    address public immutable mim;
    IBexVault public immutable bexVault;
    address[] public tokens;
    bytes32 public immutable poolId;

    constructor(IBentoBoxLite _box, IERC4626 _vault, address _mim, bytes32 _poolId) {
        box = _box;
        vault = _vault;
        mim = _mim;
        poolId = _poolId;

        address _bexVault = _vault.asset();
        bexVault = IBexVault(_bexVault);

        (address[] memory _tokens, , ) = BEX_VAULT.getPoolTokens(poolId);
        require(_tokens.length == MAX_TOKENS, ErrInvalidPool());
        tokens.push(_tokens[0]);
        tokens.push(_tokens[1]);

        _tokens[0].safeApprove(address(BEX_VAULT), type(uint256).max);
        _tokens[1].safeApprove(address(BEX_VAULT), type(uint256).max);
    }

    function swap(
        address recipient,
        uint256 shareToMin,
        uint256 shareFrom,
        bytes calldata data
    ) external override returns (uint256 extraShare, uint256 shareReturned) {
        (address[] memory to, bytes[] memory swapData) = abi.decode(data, (address[], bytes[]));
        box.withdraw(mim, address(this), address(this), 0, shareFrom);

        // MIM -> Token0
        {
            if (IERC20Metadata(mim).allowance(address(this), to[0]) != type(uint256).max) {
                mim.safeApprove(to[0], type(uint256).max);
            }

            (bool success, ) = to[0].call(swapData[0]);
            if (!success) {
                revert ErrSwapFailed();
            }
        }

        // MIM -> Token1
        {
            if (IERC20Metadata(mim).allowance(address(this), to[1]) != type(uint256).max) {
                mim.safeApprove(to[1], type(uint256).max);
            }

            (bool success, ) = to[1].call(swapData[1]);
            if (!success) {
                revert ErrSwapFailed();
            }
        }

        uint256[] memory maxAmountsIn = new uint256[](MAX_TOKENS);
        maxAmountsIn[0] = tokens[0].balanceOf(address(this));
        maxAmountsIn[1] = tokens[1].balanceOf(address(this));

        bexVault.joinPool(
            poolId,
            address(this),
            payable(address(this)),
            JoinPoolRequest({assets: tokens, maxAmountsIn: maxAmountsIn, userData: "", fromInternalBalance: false})
        );

        uint256 _amount = address(bexVault).balanceOf(address(this));
        _amount = vault.deposit(_amount, address(box));

        // Refund remaining mim balance to the recipient
        uint256 balance = mim.balanceOf(address(this));
        if (balance > 0) {
            mim.safeTransfer(recipient, balance);
        }

        // Refund remaining tokens to the recipient
        balance = tokens[0].balanceOf(address(this));
        if (balance > 0) {
            tokens[0].safeTransfer(recipient, balance);
        }
        balance = tokens[1].balanceOf(address(this));
        if (balance > 0) {
            tokens[1].safeTransfer(recipient, balance);
        }

        (, shareReturned) = box.deposit(address(vault), address(box), recipient, _amount, 0);

        extraShare = shareReturned - shareToMin;
    }
}
