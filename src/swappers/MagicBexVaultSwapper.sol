// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {IBentoBoxLite} from "/interfaces/IBentoBoxV1.sol";
import {ISwapperV2} from "/interfaces/ISwapperV2.sol";
import {IERC4626} from "/interfaces/IERC4626.sol";
import {BexLib} from "../libraries/BexLib.sol";

contract MagicBexVaultSwapper is ISwapperV2 {
    using SafeTransferLib for address;

    error ErrSwapFailed();
    error ErrInvalidPool();
    error ErrNotAllowed();

    IBentoBoxLite public immutable box;
    IERC4626 public immutable vault;
    address public immutable mim;
    address[] public tokens;
    bytes32 public immutable poolId;

    receive() external payable {
        revert ErrNotAllowed();
    }

    constructor(IBentoBoxLite _box, IERC4626 _vault, address _mim, bytes32 _poolId) {
        box = _box;
        vault = _vault;
        mim = _mim;
        poolId = _poolId;

        require(BexLib.getValidatedPool(_poolId) == _vault.asset(), ErrInvalidPool());
        tokens = BexLib.getPoolTokens(poolId);
        mim.safeApprove(address(_box), type(uint256).max);
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

        // ERC4626 -> BexVault
        amount = IERC4626(address(vault)).redeem(amount, address(this), address(this));

        // Pool -> Token0, Token1
        // using the min amount out to 0 as it will be
        // checked later with the min MIM share out
        BexLib.exitPool(poolId, tokens, amount, new uint256[](2), address(this));

        // Token0 -> MIM
        {
            if (IERC20Metadata(tokens[0]).allowance(address(this), to[0]) != type(uint256).max) {
                tokens[0].safeApprove(to[0], type(uint256).max);
            }

            Address.functionCall(to[0], swapData[0]);

            // Refund remaining balances to the recipient
            uint256 balance = tokens[0].balanceOf(address(this));
            if (balance > 0) {
                tokens[0].safeTransfer(recipient, balance);
            }
        }

        // Token1 -> MIM
        {
            if (IERC20Metadata(tokens[1]).allowance(address(this), to[1]) != type(uint256).max) {
                tokens[1].safeApprove(to[1], type(uint256).max);
            }

            Address.functionCall(to[1], swapData[1]);

            uint256 balance = tokens[1].balanceOf(address(this));
            if (balance > 0) {
                tokens[1].safeTransfer(recipient, balance);
            }
        }

        (, shareReturned) = box.deposit(mim, address(this), recipient, mim.balanceOf(address(this)), 0);
        extraShare = shareReturned - shareToMin;
    }
}
