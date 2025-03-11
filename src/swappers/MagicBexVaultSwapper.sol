// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {IBentoBoxLite} from "/interfaces/IBentoBoxV1.sol";
import {ISwapperV2} from "/interfaces/ISwapperV2.sol";
import {IERC4626} from "/interfaces/IERC4626.sol";
import {IBexVault, ExitPoolRequest} from "/interfaces/IBexVault.sol";

contract MagicBexVaultSwapper is ISwapperV2 {
    using SafeTransferLib for address;

    error ErrSwapFailed();
    error ErrInvalidPool();
    error ErrNotAllowed();

    IBexVault public constant BEX_VAULT = IBexVault(0x4Be03f781C497A489E3cB0287833452cA9B9E80B);
    uint256 public constant MAX_TOKENS = 2;

    IBentoBoxLite public immutable box;
    IERC4626 public immutable vault;
    address public immutable mim;
    IBexVault public immutable bexVault;
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

        address _bexVault = _vault.asset();
        bexVault = IBexVault(_bexVault);

        (address[] memory _tokens, , ) = IBexVault(address(_vault)).getPoolTokens(poolId);
        require(_tokens.length == MAX_TOKENS, ErrInvalidPool());
        tokens[0] = _tokens[0];
        tokens[1] = _tokens[1];

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
        IERC4626(address(vault)).redeem(amount, address(this), address(this));

        uint256[] memory minAmountsOut = new uint256[](MAX_TOKENS);
        minAmountsOut[0] = 0;
        minAmountsOut[1] = 0;

        // Pool -> Token0, Token1
        bexVault.exitPool(
            poolId,
            address(this),
            payable(address(this)),
            ExitPoolRequest({assets: tokens, minAmountsOut: minAmountsOut, userData: "", toInternalBalance: false})
        );

        // Token0 -> MIM
        {
            if (IERC20Metadata(tokens[0]).allowance(address(this), to[0]) != type(uint256).max) {
                tokens[0].safeApprove(to[0], type(uint256).max);
            }

            (bool success, ) = to[0].call(swapData[0]);
            if (!success) {
                revert ErrSwapFailed();
            }

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

            (bool success, ) = to[1].call(swapData[1]);
            if (!success) {
                revert ErrSwapFailed();
            }

            uint256 balance = tokens[1].balanceOf(address(this));
            if (balance > 0) {
                tokens[1].safeTransfer(recipient, balance);
            }
        }

        (, shareReturned) = box.deposit(mim, address(this), recipient, mim.balanceOf(address(this)), 0);
        extraShare = shareReturned - shareToMin;
    }
}
