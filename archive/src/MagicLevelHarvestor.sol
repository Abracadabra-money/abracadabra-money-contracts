// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/interfaces/IERC20.sol";
import "BoringSolidity/BoringOwnable.sol";
import "BoringSolidity/libraries/BoringERC20.sol";
import "BoringSolidity/libraries/BoringRebase.sol";
import "libraries/SafeApprove.sol";
import "libraries/MathLib.sol";
import "mixins/Operatable.sol";
import "mixins/FeeCollectable.sol";
import "interfaces/IMagicLevelRewardHandler.sol";
import "interfaces/IERC4626.sol";
import "interfaces/ILevelFinanceStaking.sol";

/// @notice Contract to harvest rewards from the staking contract and distribute them to the vault
contract MagicLevelHarvestor is Operatable, FeeCollectable {
    using BoringERC20 for IERC20;
    using SafeApproveLib for IERC20;

    error ErrSwapFailed();
    event LogFeeParametersChanged(address indexed feeCollector, uint16 feeAmount);
    event LogExchangeRouterChanged(address indexed previous, address indexed current);
    event LogHarvest(address indexed vault, uint256 total, uint256 amount, uint256 fee);

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
        (ILevelFinanceStaking staking, uint256 pid) = IMagicLevelRewardHandler(vault).stakingInfo();
        return staking.pendingReward(pid, address(vault));
    }

    /// @notice Returns the total amount of rewards in the contract (including the staking contract)
    function totalRewardsBalanceAfterClaiming(address vault) external view returns (uint256) {
        return claimable(vault) + rewardToken.balanceOf(vault) + rewardToken.balanceOf(address(this));
    }

    /// @notice Harvests rewards from the staking contract and distributes them to the vault
    /// @param minLp Minimum amount of LP tokens to mint otherwise revert
    /// @param tokenIn Token to swap rewards to and used to mint LP tokens
    /// @param maxAmountIn Maximum amount of tokenIn to swap
    /// @param swapData exchange router data for the swap
    function run(address vault, uint256 minLp, IERC20 tokenIn, uint256 maxAmountIn, bytes memory swapData) external onlyOperators {
        IMagicLevelRewardHandler(vault).harvest(address(this));

        // LVL -> tokenIn
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
        (ILevelFinanceStaking staking, ) = IMagicLevelRewardHandler(address(vault)).stakingInfo();
        ILevelFinanceLiquidityPool pool = staking.levelPool();

        uint balanceLpBefore = asset.balanceOf(address(this));
        pool.addLiquidity(address(asset), address(tokenIn), amountIn, minLp, address(this));
        totalAmount = asset.balanceOf(address(this)) - balanceLpBefore;

        (assetAmount, feeAmount) = calculateFees(totalAmount);

        if (feeAmount > 0) {
            asset.safeTransfer(feeCollector, feeAmount);
        }

        IMagicLevelRewardHandler(vault).distributeRewards(assetAmount);
        lastExecution = uint64(block.timestamp);

        emit LogHarvest(vault, totalAmount, assetAmount, feeAmount);
    }
}
