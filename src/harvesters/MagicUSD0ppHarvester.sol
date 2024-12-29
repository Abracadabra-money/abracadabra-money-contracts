// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {OwnableRoles} from "@solady/auth/OwnableRoles.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {FeeCollectable} from "/mixins/FeeCollectable.sol";
import {IERC4626} from "/interfaces/IERC4626.sol";
import {MagicUSD0pp} from "/tokens/MagicUSD0pp.sol";

contract MagicUSD0ppHarvester is OwnableRoles, FeeCollectable {
    using SafeTransferLib for address;

    error ErrSwapFailed();
    error ErrRouterNotAllowed();
    error ErrMinAmountOutNotReached();

    event LogHarvest(uint256 total, uint256 amount, uint256 fee);
    event LogAllowedRouterChanged(address indexed router, bool indexed allowed);

    uint256 public constant ROLE_OPERATOR = _ROLE_0;

    MagicUSD0pp public immutable vault;
    address public immutable asset;
    address public immutable reward;
    mapping(address => bool) public allowedRouters;

    constructor(MagicUSD0pp _vault, address _owner, address _reward) {
        vault = _vault;
        reward = _reward;
        _initializeOwner(_owner);

        asset = IERC4626(address(vault)).asset();
        asset.safeApprove(address(vault), type(uint256).max);
    }

    ////////////////////////////////////////////////////////////////////////////////
    // Operators
    ////////////////////////////////////////////////////////////////////////////////

    function run(address router, bytes memory swapData, uint256 minAmountOut) external onlyOwnerOrRoles(ROLE_OPERATOR) {
        if (!allowedRouters[router]) {
            revert ErrRouterNotAllowed();
        }

        vault.harvest(address(this));

        (bool success, ) = router.call(swapData);
        if (!success) {
            revert ErrSwapFailed();
        }

        uint256 totalAmount = asset.balanceOf(address(this));
        if (totalAmount < minAmountOut) {
            revert ErrMinAmountOutNotReached();
        }

        (uint256 assetAmount, uint256 feeAmount) = _calculateFees(totalAmount);

        if (feeAmount > 0) {
            asset.safeTransfer(feeCollector, feeAmount);
        }

        vault.distributeRewards(assetAmount);
        emit LogHarvest(totalAmount, assetAmount, feeAmount);
    }

    ////////////////////////////////////////////////////////////////////////////////
    // Admin
    ////////////////////////////////////////////////////////////////////////////////

    function setAllowedRouter(address _router, bool _allowed) external onlyOwner {
        if (allowedRouters[_router] == _allowed) {
            return;
        }

        allowedRouters[_router] = _allowed;

        if (_allowed) {
            reward.safeApprove(_router, type(uint256).max);
        } else {
            reward.safeApprove(_router, 0);
        }

        emit LogAllowedRouterChanged(_router, _allowed);
    }

    ////////////////////////////////////////////////////////////////////////////////
    // Internals
    ////////////////////////////////////////////////////////////////////////////////

    function _isFeeOperator(address account) internal view override returns (bool) {
        return account == owner();
    }
}
