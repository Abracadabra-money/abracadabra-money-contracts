// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {BoringERC20} from "BoringSolidity/libraries/BoringERC20.sol";
import {Rebase} from "BoringSolidity/libraries/BoringRebase.sol";
import {SafeApprove} from "libraries/SafeApprove.sol";
import {MathLib} from "libraries/MathLib.sol";
import {Operatable} from "mixins/Operatable.sol";
import {FeeCollectable} from "mixins/FeeCollectable.sol";
import {IMagicCurveLpRewardHandler} from "interfaces/IMagicCurveLpRewardHandler.sol";
import {IERC4626} from "interfaces/IERC4626.sol";
import {ICurveRewardGauge} from "interfaces/ICurveRewardGauge.sol";
import {ICurvePool} from "interfaces/ICurvePool.sol";

/// @notice Contract to harvest rewards from the staking contract and distribute them to the vault
contract MagicCurveLpHarvestor is Operatable, FeeCollectable {
    using BoringERC20 for IERC20;
    using SafeApprove for IERC20;

    error ErrSwapFailed();
    event LogFeeParametersChanged(address indexed feeCollector, uint16 feeAmount);
    event LogExchangeRouterChanged(address indexed previous, address indexed current);
    event LogHarvest(address indexed vault, uint256 total, uint256 amount, uint256 fee);

    uint256 public constant BIPS = 10_000;

    /// @notice Reward token to harvest
    IERC20 public immutable rewardToken;

    /// @notice Exchange router to swap rewards
    address public exchangeRouter;

    /// @notice Last time the harvest happened
    uint64 public lastExecution;

    /// @param _rewardToken Reward token to harvest
    constructor(IERC20 _rewardToken) {
        rewardToken = _rewardToken;
    }

    /// @notice Returns true when the caller is the fee operator
    function isFeeOperator(address account) public view override returns (bool) {
        return account == owner;
    }

    /// @notice Returns the number of rewards amount from the staking contract
    function claimable(address vault) public view returns (uint256) {
        ICurveRewardGauge staking = IMagicCurveLpRewardHandler(vault).staking();
        return staking.claimable_reward(address(vault), address(rewardToken));
    }

    /// @notice Returns the total amount of rewards in the contract (including the staking contract)
    function totalRewardsBalanceAfterClaiming(address vault) external view returns (uint256) {
        return claimable(vault) + rewardToken.balanceOf(address(this));
    }

    /// @notice Harvests rewards from the staking contract and distributes them to the vault
    /// @param minLp Minimum amount of LP tokens to mint otherwise revert
    /// @param tokenIn Token to swap rewards to and used to mint LP tokens
    /// @param maxAmountIn Maximum amount of tokenIn to swap
    /// @param swapData exchange router data for the swap
    function run(address vault, uint256 minLp, IERC20 tokenIn, uint256 maxAmountIn, bytes memory swapData) external onlyOperators {
        IMagicCurveLpRewardHandler(vault).harvest(address(this));

        // wKAVA -> USDT
        (bool success, ) = exchangeRouter.call(swapData);
        if (!success) {
            revert ErrSwapFailed();
        }
        uint256 amountIn = MathLib.min(tokenIn.balanceOf(address(this)), maxAmountIn);

        if (amountIn > 0) {
            _compoundFromToken(vault, tokenIn, amountIn, minLp);
        }
    }

    /// @notice Harvests rewards from the staking contract and distributes them to the vault
    function compoundFromToken(address vault, IERC20 tokenIn, uint256 amount, uint256 minLp) external onlyOperators {
        _compoundFromToken(vault, tokenIn, amount, minLp);
    }

    /// @notice Changes the allowance of the reward token to the staking contract
    function setLiquidityPoolAllowance(address pool, IERC20 token, uint256 amount) external onlyOwner {
        token.approve(pool, amount);
    }

    /// @notice Changes the allowance of the LLP tokens to the vault for `distributeRewards`
    function setVaultAssetAllowance(IERC4626 vault, uint256 amount) external onlyOwner {
        IERC20 asset = vault.asset();
        asset.approve(address(vault), amount);
    }

    /// @notice Changes the exchange router to swap the rewards to
    function setExchangeRouter(address _exchangeRouter) external onlyOwner {
        if (exchangeRouter != address(0)) {
            rewardToken.approve(exchangeRouter, 0);
        }

        emit LogExchangeRouterChanged(exchangeRouter, _exchangeRouter);
        exchangeRouter = _exchangeRouter;
        rewardToken.approve(_exchangeRouter, type(uint256).max);
    }

    function _compoundFromToken(
        address vault,
        IERC20 tokenIn,
        uint256 amountIn,
        uint256 minLp
    ) private returns (uint256 totalAmount, uint256 assetAmount, uint256 feeAmount) {
        IERC20 asset = IERC4626(vault).asset();
        uint balanceLpBefore = asset.balanceOf(address(this));
        tokenIn.safeApprove(address(asset), amountIn);
        uint256[2] memory amounts = [amountIn, 0];
        ICurvePool(address(asset)).add_liquidity(amounts, minLp);
        totalAmount = asset.balanceOf(address(this)) - balanceLpBefore;

        (assetAmount, feeAmount) = calculateFees(totalAmount);

        if (feeAmount > 0) {
            asset.safeTransfer(feeCollector, feeAmount);
        }

        IMagicCurveLpRewardHandler(vault).distributeRewards(assetAmount);
        lastExecution = uint64(block.timestamp);

        emit LogHarvest(vault, totalAmount, assetAmount, feeAmount);
    }
}
