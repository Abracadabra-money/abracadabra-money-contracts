// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/libraries/BoringERC20.sol";
import "BoringSolidity/BoringOwnable.sol";
import {GmxGlpWrapperData} from "tokens/GmxGlpWrapper.sol";
import "interfaces/IGmxGlpManager.sol";
import "interfaces/IGmxRewardRouterV2.sol";
import "interfaces/IGmxStakedGlp.sol";
import "interfaces/IGmxVester.sol";
import "forge-std/console2.sol";

/// @dev When making a new version, never change existing variables, always add after
/// the existing one.
contract GmxGlpRewardHandler is GmxGlpWrapperData {
    using BoringERC20 for IERC20;

    error ErrInvalidFeePercent();
    error ErrUnsupportedRewardToken(IERC20 token);
    error ErrUnsupportedOutputToken(IERC20 token);

    error ErrSwapFailed();
    error ErrInsufficientAmountOut();
    error ErrRecipientNotAllowed(address recipient);

    event LogFeeParametersChanged(address indexed feeCollector, uint256 feeAmount);
    event LogRewardRouterChanged(IGmxRewardRouterV2 indexed previous, IGmxRewardRouterV2 indexed current);
    event LogFeeChanged(uint256 previousFee, uint256 newFee, address previousFeeCollector, address newFeeCollector);
    event LogSwapperChanged(address indexed oldSwapper, address indexed newSwapper);
    event LogRewardSwapped(IERC20 indexed token, uint256 total, uint256 amountOut, uint256 feeAmount);
    event LogRewardTokenUpdated(IERC20 indexed token, bool enabled);
    event LogSwappingTokenOutUpdated(IERC20 indexed token, bool enabled);
    event LogAllowedSwappingRecipientUpdated(address indexed previous, bool enabled);

    /// @dev V1 variables, do not change.
    IGmxRewardRouterV2 public rewardRouter;
    address public feeCollector;
    uint8 public feePercent;
    address public swapper;
    mapping(IERC20 => bool) public rewardTokenEnabled;
    mapping(IERC20 => bool) public swappingTokenOutEnabled;
    mapping(address => bool) public allowedSwappingRecipient;

    /// @dev V2
    // Add new variables here in case of V2.

    /// @dev always leave constructor empty since this won't change GmxGlpWrapper
    /// storage anyway.
    constructor() {}

    function harvest() external {
        rewardRouter.handleRewards({
            shouldClaimGmx: true,
            shouldStakeGmx: true,
            shouldClaimEsGmx: true,
            shouldStakeEsGmx: true,
            shouldStakeMultiplierPoints: true,
            shouldClaimWeth: true,
            shouldConvertWethToEth: false
        });
    }

    function swapRewards(
        uint256 amountOutMin,
        IERC20 rewardToken,
        IERC20 outputToken,
        address recipient,
        bytes calldata data
    ) external onlyStrategyExecutor returns (uint256 amountOut) {
        if (!rewardTokenEnabled[rewardToken]) {
            revert ErrUnsupportedRewardToken(rewardToken);
        }
        if (!swappingTokenOutEnabled[outputToken]) {
            revert ErrUnsupportedOutputToken(outputToken);
        }
        if (!allowedSwappingRecipient[recipient]) {
            revert ErrRecipientNotAllowed(recipient);
        }

        uint256 amountBefore = IERC20(outputToken).balanceOf(address(this));
        rewardToken.approve(swapper, rewardToken.balanceOf(address(this)));

        (bool success, ) = swapper.call(data);
        if (!success) {
            revert ErrSwapFailed();
        }

        uint256 total = IERC20(outputToken).balanceOf(address(this)) - amountBefore;

        if (total < amountOutMin) {
            revert ErrInsufficientAmountOut();
        }

        uint256 feeAmount = (total * feePercent) / 100;
        if (feeAmount > 0) {
            amountOut = total - feeAmount;
            IERC20(outputToken).safeTransfer(feeCollector, feeAmount);
        }

        IERC20(outputToken).safeTransfer(recipient, amountOut);
        rewardToken.approve(swapper, 0);
        emit LogRewardSwapped(rewardToken, total, amountOut, feeAmount);
    }

    function setFeeParameters(address _feeCollector, uint8 _feePercent) external onlyOwner {
        if (feePercent > 100) {
            revert ErrInvalidFeePercent();
        }

        feeCollector = _feeCollector;
        feePercent = _feePercent;

        emit LogFeeParametersChanged(_feeCollector, _feePercent);
    }

    /// @param token The allowed reward tokens to swap
    function setRewardTokenEnabled(IERC20 token, bool enabled) external onlyOwner {
        rewardTokenEnabled[token] = enabled;
        emit LogRewardTokenUpdated(token, enabled);
    }

    /// @param token The allowed token out support when swapping rewards
    function setSwappingTokenOutEnabled(IERC20 token, bool enabled) external onlyOwner {
        swappingTokenOutEnabled[token] = enabled;
        emit LogSwappingTokenOutUpdated(token, enabled);
    }

    /// @param recipient Allowed recipient for token out when swapping
    function setAllowedSwappingRecipient(address recipient, bool enabled) external onlyOwner {
        allowedSwappingRecipient[recipient] = enabled;
        emit LogAllowedSwappingRecipientUpdated(recipient, enabled);
    }

    function setRewardRouter(IGmxRewardRouterV2 _rewardRouter) external onlyOwner {
        emit LogRewardRouterChanged(rewardRouter, _rewardRouter);
        rewardRouter = _rewardRouter;
    }

    function setSwapper(address _swapper) external onlyOwner {
        emit LogSwapperChanged(swapper, _swapper);
        swapper = _swapper;
    }

    ///////////////////////////////////////////////////////////////////////
    // GMX/esGMX Handling
    // Thanks to RageTrade

    /// @notice unstakes and vest protocol esGmx to convert it to Gmx
    function unstakeAndVestEsGmx(uint256 amount) external onlyOwner {
        // unstakes the protocol esGMX and starts vesting it
        // this encumbers some glp deposits
        // can stop vesting to enable glp withdraws
        rewardRouter.unstakeEsGmx(amount);
        IGmxVester(rewardRouter.glpVester()).deposit(amount);
    }

    /// @notice claims vested gmx tokens (i.e. stops vesting esGmx so that the relevant glp amount is unlocked)
    /// @dev when esGmx is vested some GlP tokens are locked on a pro-rata basis, in case that leads to issue in withdrawal this function can be called
    function stopVestAndStakeEsGmx() external onlyOwner {
        // stops vesting and stakes the remaining esGMX
        // this enables glp withdraws
        IGmxVester(rewardRouter.glpVester()).withdraw();
        uint256 esGmxWithdrawn = IERC20(rewardRouter.esGmx()).balanceOf(address(this));
        rewardRouter.stakeEsGmx(esGmxWithdrawn);
    }

    /// @notice claims vested gmx tokens to feeRecipient
    /// @dev vested esGmx gets converted to GMX every second, so whatever amount is vested gets claimed
    function claimVestedGmx() external onlyOwner {
        // stops vesting and stakes the remaining esGMX
        // this can be used in case glp withdraws are hampered
        uint256 gmxClaimed = IGmxVester(rewardRouter.glpVester()).claim();

        //Transfer all of the gmx received to fee recipient
        IERC20(rewardRouter.gmx()).safeTransfer(feeCollector, gmxClaimed);
    }
}
