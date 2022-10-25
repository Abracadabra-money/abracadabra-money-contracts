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

    event LogAccrue(uint256 accruedAmount);
    event LogInterestChange(uint64 oldInterestRate, uint64 newInterestRate, uint64 incrementPerSecond, uint64 maxInterestPerSecond);
    event FeeToChanged(address previous, address current);
    event SwapperChanged(address previous, address current);
    event Swap(uint256 amountIn, uint256 amountOut);
    event SwapTokenOutEnabled(IERC20 token, bool enabled);
    event SwapAndWithdrawFee(uint256 amountIn, uint256 amountOut, IERC20 tokenOut);
    event WithdrawFee(uint256 amount);
    event EmergencyExitEnabled(bool enabled);

    uint256 public constant INTEREST_PER_SECOND_TO_YEAR_CONVERSION = 316880878;

    struct AccrueInfo {
        // slot 0
        uint64 lastAccrued;
        uint64 interestPerSecond;
        uint64 incrementPerSecond;
        uint64 maxInterestPerSecond;
        // slot 1
        uint256 pendingFeeEarned;
    }

    address public feeTo;
    address public swapper;
    uint256 public principal;
    bool public emergencyExitEnabled;

    AccrueInfo public accrueInfo;

    mapping(IERC20 => bool) public swapTokenOutEnabled;

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

    function _skim(uint256) internal override {
        principal = availableAmount();
    }

    /// @notice accrue interest and report loss balance change
    function _harvest(uint256) internal override returns (int256) {
        return accrue();
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

        accrue();
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

        if (balance > accrueInfo.pendingFeeEarned) {
            amount = balance - accrueInfo.pendingFeeEarned;
        }
    }

    function withdrawFee(uint128 amount) external onlyExecutor {
        if (amount > accrueInfo.pendingFeeEarned) {
            amount = uint128(accrueInfo.pendingFeeEarned);
        }

        accrueInfo.pendingFeeEarned -= amount;
        IERC20(strategyToken).safeTransfer(feeTo, amount);
        emit WithdrawFee(amount);
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
        accrueInfo.pendingFeeEarned -= amountIn;

        tokenOut.safeTransfer(feeTo, amountOut);
        emit SwapAndWithdrawFee(amountIn, amountOut, tokenOut);
    }

    function accrue() public returns (int256) {
        // Number of seconds since accrue was called
        uint256 elapsedTime = block.timestamp - accrueInfo.lastAccrued;
        if (elapsedTime == 0) {
            return int256(0);
        }

        accrueInfo.lastAccrued = uint64(block.timestamp);

        if (principal == 0) {
            accrueInfo = accrueInfo;
            return int256(0);
        }

        // Accrue interest
        uint256 interest = (principal * accrueInfo.interestPerSecond * elapsedTime) / 1e18;
        accrueInfo.pendingFeeEarned += interest;

        emit LogAccrue(interest);

        // dynamic interest rate buildup
        if (accrueInfo.incrementPerSecond > 0 && accrueInfo.interestPerSecond < accrueInfo.maxInterestPerSecond) {
            accrueInfo.interestPerSecond += uint64(elapsedTime * accrueInfo.incrementPerSecond);

            if (accrueInfo.interestPerSecond > accrueInfo.maxInterestPerSecond) {
                accrueInfo.interestPerSecond = accrueInfo.maxInterestPerSecond;
                accrueInfo.incrementPerSecond = 0;
            }
        }

        return -int256(interest);
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

    function changeInterestRate(
        uint64 startingInterestPerSecond,
        uint64 destinationInterestPerSecond,
        uint256 durationInSeconds
    ) public onlyOwner {
        accrue();

        accrueInfo.interestPerSecond = startingInterestPerSecond;

        if (durationInSeconds > 0 && destinationInterestPerSecond > startingInterestPerSecond) {
            accrueInfo.incrementPerSecond = uint64((destinationInterestPerSecond - startingInterestPerSecond) / durationInSeconds);
            accrueInfo.maxInterestPerSecond = destinationInterestPerSecond;
        } else {
            accrueInfo.incrementPerSecond = 0;
            accrueInfo.maxInterestPerSecond = startingInterestPerSecond;
        }

        emit LogInterestChange(
            accrueInfo.interestPerSecond,
            startingInterestPerSecond,
            accrueInfo.incrementPerSecond,
            accrueInfo.maxInterestPerSecond
        );
    }

    function parameters()
        external
        view
        returns (
            uint256 yearlyInterestRateBips,
            uint256 maxYearlyInterestRateBips,
            uint256 increasePerSecondE7
        )
    {
        yearlyInterestRateBips = (accrueInfo.interestPerSecond * 100) / INTEREST_PER_SECOND_TO_YEAR_CONVERSION;
        maxYearlyInterestRateBips = (accrueInfo.maxInterestPerSecond * 100) / INTEREST_PER_SECOND_TO_YEAR_CONVERSION;
        increasePerSecondE7 = (accrueInfo.incrementPerSecond * 1e7) / INTEREST_PER_SECOND_TO_YEAR_CONVERSION;
    }

    function setEmergencyExitEnabled(bool _emergencyExitEnabled) external onlyOwner {
        emergencyExitEnabled = _emergencyExitEnabled;
        emit EmergencyExitEnabled(_emergencyExitEnabled);
    }

    function _withdraw(uint256) internal override {}

    function _exit() internal override {}
}
