// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {OwnableOperators} from "/mixins/OwnableOperators.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICauldronV4} from "/interfaces/ICauldronV4.sol";
import {ISwapperV2} from "/interfaces/ISwapperV2.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {IBentoBoxLite} from "/interfaces/IBentoBoxV1.sol";

interface SDEUSD {
    function asset() external view returns (address);

    function unstake(address receiver) external;

    function cooldownShares(uint256 shares) external returns (uint256 assets);
}

contract SdeusdPermissionedSwapper is ISwapperV2, OwnableOperators {
    using SafeTransferLib for address;

    address public immutable deusd;
    address public immutable sdeusd;
    address public immutable mim;

    constructor(address sdeusd_, address mim_, address owner_) {
        _initializeOwner(owner_);

        sdeusd = sdeusd_;
        deusd = SDEUSD(sdeusd_).asset();
        mim = mim_;
    }

    function swap(
        address /* token */,
        address /* mim */,
        address recipient,
        uint256 shareToMin,
        uint256 shareFrom,
        bytes calldata data
    ) public onlyOperators returns (uint256 extraShare, uint256 shareReturned) {
        IBentoBoxLite box = IBentoBoxLite(ICauldronV4(msg.sender).bentoBox());
        (uint256 amount, ) = box.withdraw(sdeusd, address(this), address(this), 0, shareFrom);

        // sdeusd -> deusd
        uint256 amountOut = SDEUSD(sdeusd).cooldownShares(amount);
        SDEUSD(sdeusd).unstake(address(box));

        (address to, bytes memory swapData) = abi.decode(data, (address, bytes));
        (, shareFrom) = box.deposit(deusd, address(box), to, amountOut, 0);

        return ISwapperV2(to).swap(deusd, mim, recipient, shareToMin, shareFrom, swapData);
    }
}
