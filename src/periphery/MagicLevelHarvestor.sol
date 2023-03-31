// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/interfaces/IERC20.sol";
import "BoringSolidity/BoringOwnable.sol";
import "BoringSolidity/libraries/BoringERC20.sol";
import "BoringSolidity/libraries/BoringRebase.sol";
import "libraries/SafeApprove.sol";
import "libraries/MathLib.sol";
import "periphery/Operatable.sol";
import "periphery/FeeCollectable.sol";
import "interfaces/IMagicLevelRewardHandler.sol";
import "interfaces/IERC4626.sol";
import "interfaces/ILevelFinanceStaking.sol";

contract MagicLevelHarvestor is Operatable, FeeCollectable {
    using BoringERC20 for IERC20;
    using SafeApprove for IERC20;

    error ErrSwapFailed();
    event LogFeeParametersChanged(address indexed feeCollector, uint16 feeAmount);
    event LogExchangeRouterChanged(address indexed previous, address indexed current);
    event LogHarvest(uint256 total, uint256 amount, uint256 fee);

    uint256 public constant BIPS = 10_000;

    IERC20 public immutable rewardToken;
    IERC20 public immutable asset;
    IERC4626 public immutable vault;

    address public exchangeRouter;
    uint64 public lastExecution;

    constructor(IERC20 _rewardToken, IERC4626 _vault) {
        rewardToken = _rewardToken;
        vault = _vault;

        IERC20 _asset = _vault.asset();
        _asset.approve(address(_vault), type(uint256).max);
        asset = _asset;
    }

    function isFeeOperator(address account) public view override returns (bool) {
        return account == owner;
    }

    function claimable() public view returns (uint256) {
        (ILevelFinanceStaking staking, uint256 pid) = IMagicLevelRewardHandler(address(vault)).stakingInfo();
        return staking.pendingReward(pid, address(vault));
    }

    function totalRewardsBalanceAfterClaiming() external view returns (uint256) {
        return claimable() + rewardToken.balanceOf(address(vault)) + rewardToken.balanceOf(address(this));
    }

    function run(uint256 minLp, IERC20 tokenIn, uint256 maxAmountIn, bytes memory swapData) external onlyOperators {
        IMagicLevelRewardHandler(address(vault)).harvest(address(this));

        // LVL -> tokenIn
        (bool success, ) = exchangeRouter.call(swapData);
        if (!success) {
            revert ErrSwapFailed();
        }
        uint256 amountIn = MathLib.min(tokenIn.balanceOf(address(this)), maxAmountIn);

        if (amountIn > 0) {
            _compoundFromToken(tokenIn, amountIn, minLp);
        }
    }

    function compoundFromToken(IERC20 tokenIn, uint256 amount, uint256 minLp) external onlyOperators {
        _compoundFromToken(tokenIn, amount, minLp);
    }

    function _compoundFromToken(
        IERC20 tokenIn,
        uint256 amountIn,
        uint256 minLp
    ) private returns (uint256 totalAmount, uint256 assetAmount, uint256 feeAmount) {
        (ILevelFinanceStaking staking, ) = IMagicLevelRewardHandler(address(vault)).stakingInfo();
        ILevelFinanceLiquidityPool pool = staking.levelPool();

        uint balanceLpBefore = asset.balanceOf(address(this));
        pool.addLiquidity(address(asset), address(tokenIn), amountIn, minLp, address(this));
        totalAmount = asset.balanceOf(address(this)) - balanceLpBefore;

        (assetAmount, feeAmount) = calculateFees(totalAmount);

        if (feeAmount > 0) {
            asset.safeTransfer(feeCollector, feeAmount);
        }

        IMagicLevelRewardHandler(address(vault)).distributeRewards(assetAmount);
        lastExecution = uint64(block.timestamp);

        emit LogHarvest(totalAmount, assetAmount, feeAmount);
    }

    function setLiquidityPoolAllowance(IERC20 token, uint256 amount) external onlyOwner {
        (ILevelFinanceStaking staking, ) = IMagicLevelRewardHandler(address(vault)).stakingInfo();
        token.approve(address(staking.levelPool()), amount);
    }

    function setExchangeRouter(address _exchangeRouter) external onlyOwner {
        if(exchangeRouter != address(0)) {
            rewardToken.approve(exchangeRouter, 0);
        }

        emit LogExchangeRouterChanged(exchangeRouter, _exchangeRouter);
        exchangeRouter = _exchangeRouter;
        rewardToken.approve(_exchangeRouter, type(uint256).max);
    }
}
