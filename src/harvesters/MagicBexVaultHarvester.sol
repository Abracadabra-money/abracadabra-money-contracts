// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {OwnableRoles} from "@solady/auth/OwnableRoles.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {FeeCollectable} from "/mixins/FeeCollectable.sol";
import {IERC4626} from "/interfaces/IERC4626.sol";
import {IMagicInfraredVault} from "/interfaces/IMagicInfraredVault.sol";
import {IInfraredStaking} from "/interfaces/IInfraredStaking.sol";
import {BexLib, BEX_VAULT} from "../libraries/BexLib.sol";

/// @notice Contract to harvest rewards from the staking contract and distribute them to the vault
contract MagicBexVaultHarvester is OwnableRoles, FeeCollectable {
    using SafeTransferLib for address;

    error ErrSwapFailed();

    error ErrMinAmountOut();
    event LogExchangeRouterChanged(address indexed previous, address indexed current);
    event LogRouterChanged(address indexed previous, address indexed current);
    event LogHarvest(uint256 total, uint256 amount, uint256 fee);
    event LogTokenRescue(address indexed token, address indexed to, uint256 amount);

    uint256 public constant ROLE_OPERATOR = _ROLE_0;

    IMagicInfraredVault public immutable vault;
    address public immutable bexVault;
    bytes32 public immutable poolId;

    address public exchangeRouter;
    address[] public tokens;

    constructor(IMagicInfraredVault _vault, bytes32 _poolId, address _owner) {
        vault = _vault;
        poolId = _poolId;

        _initializeOwner(_owner);

        bexVault = IERC4626(address(_vault)).asset();
        bexVault.safeApprove(address(_vault), type(uint256).max);
        tokens = BexLib.getPoolTokens(poolId);

        tokens[0].safeApprove(address(BEX_VAULT), type(uint256).max);
        tokens[1].safeApprove(address(BEX_VAULT), type(uint256).max);
    }

    ////////////////////////////////////////////////////////////////////////////////
    // Operators
    ////////////////////////////////////////////////////////////////////////////////

    function run(bytes[] memory swaps, uint256[] memory amountsIn, uint256 minAmountOut) external onlyOwnerOrRoles(ROLE_OPERATOR) {
        vault.harvest(address(this));

        for (uint i = 0; i < swaps.length; i++) {
            bytes memory swap = swaps[i];

            if (swap.length > 0) {
                (bool success, ) = exchangeRouter.call(swap);
                if (!success) {
                    revert ErrSwapFailed();
                }
            }
        }

        BexLib.joinPool(poolId, tokens, amountsIn, minAmountOut, address(this));

        uint256 totalAmount = bexVault.balanceOf(address(this));
        (uint256 assetAmount, uint256 feeAmount) = _calculateFees(totalAmount);

        if (feeAmount > 0) {
            bexVault.safeTransfer(feeCollector, feeAmount);
        }

        vault.distributeRewards(assetAmount);
        emit LogHarvest(totalAmount, assetAmount, feeAmount);
    }

    ////////////////////////////////////////////////////////////////////////////////
    // Admin
    ////////////////////////////////////////////////////////////////////////////////

    function setExchangeRouter(address _exchangeRouter) external onlyOwner {
        IInfraredStaking staking = vault.staking();

        for (uint256 i = 0; i < staking.getAllRewardTokens().length; i++) {
            address reward = staking.rewardTokens(i);

            if (exchangeRouter != address(0)) {
                reward.safeApprove(exchangeRouter, 0);
            }
            reward.safeApprove(_exchangeRouter, type(uint256).max);
        }

        emit LogExchangeRouterChanged(exchangeRouter, _exchangeRouter);
        exchangeRouter = _exchangeRouter;
    }

    function approveToken(address token, address spender, uint256 amount) external onlyOwner {
        token.safeApprove(spender, amount);
    }

    function rescue(address token, address to, uint256 amount) external onlyOwner {
        token.safeTransfer(to, amount);
        emit LogTokenRescue(token, to, amount);
    }

    ////////////////////////////////////////////////////////////////////////////////
    // Internals
    ////////////////////////////////////////////////////////////////////////////////

    function _isFeeOperator(address account) internal view override returns (bool) {
        return account == owner();
    }
}
