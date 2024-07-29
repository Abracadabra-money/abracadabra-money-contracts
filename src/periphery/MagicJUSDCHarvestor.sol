// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC20, BoringERC20} from "@BoringSolidity/libraries/BoringERC20.sol";
import {MathLib} from "/libraries/MathLib.sol";
import {Operatable} from "/mixins/Operatable.sol";
import {SafeApproveLib} from "/libraries/SafeApproveLib.sol";
import {FeeCollectable} from "/mixins/FeeCollectable.sol";
import {IMagicJUSDCRewardHandler} from "/interfaces/IMagicJUSDCRewardHandler.sol";
import {IERC4626} from "/interfaces/IERC4626.sol";
import {IMiniChefV2} from "/interfaces/IMiniChefV2.sol";
import {IJonesRouter} from "/interfaces/IJonesRouter.sol";

/// @notice Contract to harvest rewards from the staking contract and distribute them to the vault
contract MagicJUSDCHarvestor is Operatable, FeeCollectable {
    using BoringERC20 for IERC20;
    using SafeApproveLib for IERC20;

    error ErrSwapFailed();
    error ErrInfufficientOutput();
    
    event LogFeeParametersChanged(address indexed feeCollector, uint16 feeAmount);
    event LogExchangeRouterChanged(address indexed previous, address indexed current);
    event LogHarvest(uint256 total, uint256 amount, uint256 fee);

    /// @notice Reward token to harvest
    IERC20 public immutable rewardToken;

    /// @notice Exchange router to swap rewards
    address public exchangeRouter;

    /// @notice Last time the harvest happened
    uint64 public lastExecution;

    IJonesRouter public jonesRouter;

    IERC4626 public magicJUSDC;

    IERC20 public jusdc;

    IERC20 public usdc;

    /// @param _rewardToken Reward token to harvest
    constructor(IERC4626 _magicJUSDC, IERC20 _rewardToken, IJonesRouter _jonesRouter) {
        magicJUSDC = _magicJUSDC;
        rewardToken = _rewardToken;
        jonesRouter = _jonesRouter;
        jusdc = IERC4626(_magicJUSDC).asset();
        usdc = IERC4626(address(jusdc)).asset();

        usdc.approve(address(_jonesRouter), type(uint256).max);
        jusdc.approve(address(magicJUSDC), type(uint256).max);
    }

    /// @notice Returns true when the caller is the fee operator
    function isFeeOperator(address account) public view override returns (bool) {
        return account == owner;
    }

    /// @notice Returns the number of rewards amount from the staking contract
    function claimable() public view returns (uint256) {
        (IMiniChefV2 staking, uint256 pid) = IMagicJUSDCRewardHandler(address(magicJUSDC)).stakingInfo();
        return staking.pendingSushi(pid, address(magicJUSDC));
    }

    /// @notice Returns the total amount of rewards in the contract (including the staking contract)
    function totalRewardsBalanceAfterClaiming() external view returns (uint256) {
        return claimable() + rewardToken.balanceOf(address(magicJUSDC)) + rewardToken.balanceOf(address(this));
    }

    /// @notice Harvests rewards from the staking contract and distributes them to the vault
    /// @param minOutput Minimum amount of JUSDC tokens to mint otherwise revert
    /// @param maxAmountIn Maximum amount of tokenIn to swap
    /// @param swapData exchange router data for the swap
    function run(uint256 minOutput, uint256 maxAmountIn, bytes memory swapData) external onlyOperators {
        IMagicJUSDCRewardHandler(address(magicJUSDC)).harvest(address(this));

        // ARB -> tokenIn
        (bool success, ) = exchangeRouter.call(swapData);
        if (!success) {
            revert ErrSwapFailed();
        }
        
        uint256 amountIn = MathLib.min(usdc.balanceOf(address(this)), maxAmountIn);

        if (amountIn > 0) {
            _compoundFromToken(amountIn, minOutput);
        }
    }

    /// @notice Harvests rewards from the staking contract and distributes them to the vault
    function compoundFromToken(uint256 amount, uint256 minOutput) external onlyOperators {
        _compoundFromToken(amount, minOutput);
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
        uint256 amountIn,
        uint256 minOut
    ) private returns (uint256 totalAmount, uint256 assetAmount, uint256 feeAmount) {
        uint balanceBefore = jusdc.balanceOf(address(this));
        jonesRouter.deposit(amountIn, address(this));
        totalAmount = jusdc.balanceOf(address(this)) - balanceBefore;

        if(totalAmount < minOut) {
            revert ErrInfufficientOutput();
        }

        (assetAmount, feeAmount) = calculateFees(totalAmount);

        if (feeAmount > 0) {
            jusdc.safeTransfer(feeCollector, feeAmount);
        }

        IMagicJUSDCRewardHandler(address(magicJUSDC)).distributeRewards(assetAmount);
        lastExecution = uint64(block.timestamp);

        emit LogHarvest(totalAmount, assetAmount, feeAmount);
    }
}
