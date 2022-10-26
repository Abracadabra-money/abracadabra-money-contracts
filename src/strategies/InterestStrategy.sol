// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/interfaces/IERC20.sol";
import "BoringSolidity/libraries/BoringERC20.sol";
import "./BaseStrategy.sol";
import "forge-std/console2.sol";

contract InterestStrategy is BaseStrategy {
    using BoringERC20 for IERC20;

    error InsupportedToken();
    error InvalidInterestRate();
    error SwapFailed();
    error InsufficientAmountOut();
    error InvalidFeeTo();
    error InvalidMaxInterestPerSecond();
    error InvalidLerpParameters();

    event LogAccrue(uint256 accruedAmount);
    event LogInterestChanged(uint64 interestPerSecond);
    event LogInterestWithLerpChanged(uint64 startInterestPerSecond, uint64 targetInterestPerSecond, uint64 duration);
    event FeeToChanged(address previous, address current);
    event SwapperChanged(address previous, address current);
    event Swap(uint256 amountIn, uint256 amountOut);
    event SwapTokenOutEnabled(IERC20 token, bool enabled);
    event SwapAndWithdrawFee(uint256 amountIn, uint256 amountOut, IERC20 tokenOut);
    event WithdrawFee(uint256 amount);
    event EmergencyExitEnabled(bool enabled);

    uint256 private constant WAD = 1e18;

    // Interest linear interpolation to destination in a given time
    // ex: 1% -> 13% in 30 days.
    struct InterestLerp {
        uint64 startTime;
        uint64 startInterestPerSecond;
        uint64 targetInterestPerSecond;
        uint64 duration;
    }

    // slot 0
    uint128 public pendingFeeEarned;
    uint128 public pendingFeeEarnedAdjustement;

    // slot 1
    uint64 public lastAccrued;
    uint64 public interestPerSecond;
    bool public emergencyExitEnabled;

    address public feeTo;
    address public swapper;
    uint256 public principal;
    mapping(IERC20 => bool) public swapTokenOutEnabled;
    InterestLerp public interestLerp;

    constructor(
        IERC20 _strategyToken,
        IERC20 _mim,
        IBentoBoxV1 _bentoBox,
        address _feeTo
    ) BaseStrategy(_strategyToken, _bentoBox) {
        feeTo = _feeTo;
        swapTokenOutEnabled[_mim] = true;

        emit FeeToChanged(address(0), _feeTo);
        emit SwapTokenOutEnabled(_mim, true);
    }

    function _updateInterestPerSecond() private {
        if (interestLerp.duration == 0) {
            return;
        }

        /// @dev Adapted from https://github.com/makerdao/dss-lerp/blob/master/src/Lerp.sol
        if (block.timestamp < interestLerp.startTime + interestLerp.duration) {
            uint256 t = ((block.timestamp - interestLerp.startTime) * WAD) / interestLerp.duration;
            interestPerSecond = uint64(
                (interestLerp.targetInterestPerSecond * t) /
                    WAD +
                    interestLerp.startInterestPerSecond -
                    (interestLerp.startInterestPerSecond * t) /
                    WAD
            );
        } else {
            interestPerSecond = interestLerp.targetInterestPerSecond;
            interestLerp.duration = 0;
        }
    }

    function _skim(uint256) internal override {
        principal = availableAmount();

        if (principal > 0) {
            lastAccrued = uint64(block.timestamp);
        }
    }

    /// @dev accrue interest and report loss
    function harvest(uint256 balance, address sender) external virtual override isActive onlyBentoBox returns (int256) {
        if (sender == address(this) && balance > 0) {
            uint256 accrued = _accrue();

            // add the potential accrued interest collected from changing the interest rate, since
            // this didn't harvest & reported loss yet.
            accrued += pendingFeeEarnedAdjustement;
            pendingFeeEarnedAdjustement = 0;

            return -int256(accrued);
        }

        return int256(0);
    }

    function withdraw(uint256 amount) external override isActive onlyBentoBox returns (uint256 actualAmount) {
        uint256 maxAvailableAmount = availableAmount();

        if (maxAvailableAmount > 0) {
            actualAmount = amount > maxAvailableAmount ? maxAvailableAmount : amount;
            maxAvailableAmount -= actualAmount;
            strategyToken.safeTransfer(address(bentoBox), actualAmount);
        }

        principal = maxAvailableAmount;
    }

    function exit(uint256 amount) external override onlyBentoBox returns (int256 amountAdded) {
        // in case something wrong happen, we can exit and use `afterExit` once we've exited.
        if (emergencyExitEnabled) {
            exited = true;
            return int256(0);
        }

        _accrue();
        uint256 maxAvailableAmount = availableAmount();

        if (maxAvailableAmount > 0) {
            uint256 actualAmount = amount > maxAvailableAmount ? maxAvailableAmount : amount;
            amountAdded = int256(actualAmount) - int256(amount);

            if (amountAdded > 0) {
                strategyToken.safeTransfer(address(bentoBox), actualAmount);
            }
        }

        principal = 0;
        exited = true;
    }

    function availableAmount() public view returns (uint256 amount) {
        uint256 balance = strategyToken.balanceOf(address(this));

        if (balance > pendingFeeEarned) {
            amount = balance - pendingFeeEarned;
        }
    }

    function withdrawFees() external onlyExecutor {
        IERC20(strategyToken).safeTransfer(feeTo, pendingFeeEarned);

        emit WithdrawFee(pendingFeeEarned);
        pendingFeeEarned = 0;
    }

    function swapAndwithdrawFees(
        uint256 amountOutMin,
        IERC20 tokenOut,
        bytes calldata data
    ) external onlyExecutor {
        if (!swapTokenOutEnabled[tokenOut]) {
            revert InsupportedToken();
        }

        uint256 amountInBefore = IERC20(strategyToken).balanceOf(address(this));
        uint256 amountOutBefore = tokenOut.balanceOf(address(this));

        (bool success, ) = swapper.call(data);
        if (!success) {
            revert SwapFailed();
        }

        uint256 amountOut = tokenOut.balanceOf(address(this)) - amountOutBefore;
        if (amountOut < amountOutMin) {
            revert InsufficientAmountOut();
        }

        uint256 amountIn = IERC20(strategyToken).balanceOf(address(this)) - amountInBefore;
        pendingFeeEarned -= uint128(amountIn);

        tokenOut.safeTransfer(feeTo, amountOut);
        emit SwapAndWithdrawFee(amountIn, amountOut, tokenOut);
    }

    function _accrue() private returns (uint128 interest) {
        if (lastAccrued == 0) {
            return 0;
        }

        // Number of seconds since accrue was called
        uint256 elapsedTime = block.timestamp - lastAccrued;
        if (elapsedTime == 0) {
            return 0;
        }

        lastAccrued = uint64(block.timestamp);

        if (principal == 0) {
            return 0;
        }
        console2.log("before interestPerSecond", interestPerSecond);
        console2.log("principal", principal);

        // Accrue interest
        interest = uint128((principal * interestPerSecond * elapsedTime) / 1e18);
        pendingFeeEarned += interest;

        console2.log("interest", interest);
        console2.log("pendingFeeEarned", pendingFeeEarned);

        _updateInterestPerSecond();

        console2.log("after interestPerSecond", interestPerSecond);
        console2.log("elapsedTime", elapsedTime);

        emit LogAccrue(interest);
    }

    function setFeeTo(address _feeTo) external onlyOwner {
        if (_feeTo == address(0)) {
            revert InvalidFeeTo();
        }

        emit FeeToChanged(feeTo, _feeTo);
        feeTo = _feeTo;
    }

    function setSwapper(address _swapper) external onlyOwner {
        if (swapper != address(0)) {
            strategyToken.approve(swapper, 0);
        }

        strategyToken.approve(_swapper, type(uint256).max);
        emit SwapperChanged(swapper, _swapper);
        swapper = _swapper;
    }

    function setSwapTokenOutEnabled(IERC20 token, bool enabled) external onlyOwner {
        swapTokenOutEnabled[token] = enabled;
        emit SwapTokenOutEnabled(token, enabled);
    }

    function setInterestPerSecond(uint64 _interestPerSecond) public onlyOwner {
        pendingFeeEarnedAdjustement += _accrue();
        interestPerSecond = _interestPerSecond;
        interestLerp.duration = 0;

        emit LogInterestChanged(interestPerSecond);
    }

    function setInterestPerSecondWithLerp(
        uint64 startInterestPerSecond,
        uint64 targetInterestPerSecond,
        uint64 duration
    ) public onlyOwner {
        if (duration == 0 || duration > 365 days || targetInterestPerSecond <= startInterestPerSecond) {
            revert InvalidLerpParameters();
        }

        pendingFeeEarnedAdjustement += _accrue();
        interestPerSecond = startInterestPerSecond;
        interestLerp.duration = duration;
        interestLerp.startTime = uint64(block.timestamp);
        interestLerp.startInterestPerSecond = startInterestPerSecond;
        interestLerp.targetInterestPerSecond = targetInterestPerSecond;

        emit LogInterestWithLerpChanged(startInterestPerSecond, targetInterestPerSecond, duration);
    }

    function setEmergencyExitEnabled(bool _emergencyExitEnabled) external onlyOwner {
        emergencyExitEnabled = _emergencyExitEnabled;
        emit EmergencyExitEnabled(_emergencyExitEnabled);
    }
}
