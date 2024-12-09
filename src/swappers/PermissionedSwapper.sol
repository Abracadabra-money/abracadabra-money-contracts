// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {OwnableOperators} from "/mixins/OwnableOperators.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICauldronV4} from "/interfaces/ICauldronV4.sol";
import {ISwapperV2} from "/interfaces/ISwapperV2.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {IBentoBoxLite} from "/interfaces/IBentoBoxV1.sol";

abstract contract PermissionedSwapper is ISwapperV2, OwnableOperators {
    using SafeTransferLib for address;

    address public immutable asset;

    constructor(address owner_, address asset_) {
        _initializeOwner(owner_);
        asset = asset_;
    }

    function swap(
        address vault,
        address mim,
        address recipient,
        uint256 shareToMin,
        uint256 shareFrom,
        bytes calldata data
    ) public override onlyOperators returns (uint256 extraShare, uint256 shareReturned) {
        IBentoBoxLite box = IBentoBoxLite(ICauldronV4(msg.sender).bentoBox());
        (uint256 amount, ) = box.withdraw(vault, address(this), address(this), 0, shareFrom);

        (amount) = _redeem(amount);

        asset.safeTransfer(address(box), amount);

        (address to, bytes memory swapData) = abi.decode(data, (address, bytes));
        (, shareFrom) = box.deposit(asset, address(box), to, amount, 0);
        return ISwapperV2(to).swap(asset, mim, recipient, shareToMin, shareFrom, swapData);
    }

    function _redeem(uint256 amountIn) internal virtual returns (uint256 amountOut);
}
