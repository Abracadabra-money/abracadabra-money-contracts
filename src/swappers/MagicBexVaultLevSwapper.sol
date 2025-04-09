// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {IBentoBoxLite} from "/interfaces/IBentoBoxV1.sol";
import {ILevSwapperV2} from "/interfaces/ILevSwapperV2.sol";
import {IERC4626} from "/interfaces/IERC4626.sol";
import {BexLib, BEX_VAULT} from "../libraries/BexLib.sol";

contract MagicBexVaultLevSwapper is ILevSwapperV2 {
    using SafeTransferLib for address;

    error ErrSwapFailed();
    error ErrInvalidPool();

    IBentoBoxLite public immutable box;
    address public immutable bexVault;

    IERC4626 public immutable vault;
    address public immutable mim;
    address[] public tokens;
    bytes32 public immutable poolId;

    constructor(IBentoBoxLite _box, IERC4626 _vault, address _mim, bytes32 _poolId) {
        box = _box;
        vault = _vault;
        mim = _mim;
        poolId = _poolId;

        bexVault = IERC4626(address(_vault)).asset();
        require(BexLib.getValidatedPool(_poolId) == bexVault, ErrInvalidPool());

        tokens = BexLib.getPoolTokens(poolId);
        tokens[0].safeApprove(address(BEX_VAULT), type(uint256).max);
        tokens[1].safeApprove(address(BEX_VAULT), type(uint256).max);

        bexVault.safeApprove(address(vault), type(uint256).max);
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
            Address.functionCall(to[0], swapData[0]);
        }

        // MIM -> Token1
        {
            if (IERC20Metadata(mim).allowance(address(this), to[1]) != type(uint256).max) {
                mim.safeApprove(to[1], type(uint256).max);
            }

            Address.functionCall(to[1], swapData[1]);
        }

        uint256[] memory amountsIn = new uint256[](2);
        amountsIn[0] = tokens[0].balanceOf(address(this));
        amountsIn[1] = tokens[1].balanceOf(address(this));

        BexLib.joinPool(
            poolId,
            tokens,
            amountsIn,
            0, // will be checked later with min LP share ut
            address(this)
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
