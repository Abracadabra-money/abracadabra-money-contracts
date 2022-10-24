// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/interfaces/IERC20.sol";
import "BoringSolidity/libraries/BoringERC20.sol";
import "./BaseStrategy.sol";

contract InterestStrategy is BaseStrategy {
    using BoringERC20 for IERC20;

    error InsupportedToken(IERC20 token);
    error InvalidInterestRate(uint256 rate);
    error SwapFailed();
    error InsufficientAmountOut();
    error AmountExceedsPendingFeeEarned(uint256 amount);
    error InvalidFeeTo(address feeTo);

    event LogAccrue(uint128 accruedAmount);
    event LogInterestChange(uint64 oldInterestRate, uint64 newInterestRate);
    event FeeToChanged(address previous, address current);
    event SwapperChanged(address previous, address current);
    event Swap(uint256 amountIn, uint256 amountOut);
    event SwapTokenOutEnabled(IERC20 token, bool enabled);
    event SwapAndWithdrawFee(uint256 amountIn, uint256 amountOut, IERC20 tokenOut);
    event WithdrawFee(uint256 amount);

    struct AccrueInfo {
        uint64 lastAccrued;
        uint128 pendingFeeEarned;
        uint64 interestPerSecond;
    }

    uint64 private constant ONE_PERCENT_RATE = 317097920;

    uint256 private lastInterestUpdate;
    address public feeTo;
    address public swapper;
    uint256 public principal;

    AccrueInfo public accrueInfo;

    mapping(IERC20 => bool) public swapTokenOutEnabled;

    constructor(IERC20 _strategyToken, IBentoBoxV1 _bentoBox) BaseStrategy(_strategyToken, _bentoBox) {
        feeTo = msg.sender;
    }

    function _skim(uint256) internal override {
        accrue();
        principal = availableAmount();
    }

    function _harvest(uint256 balance) internal override returns (int256 amountAdded) {}

    function _withdraw(uint256) internal override {}

    function _exit() internal override {}

    function availableAmount() public view returns (uint256 amount) {
        uint256 balance = strategyToken.balanceOf(address(this));

        if (balance > accrueInfo.pendingFeeEarned) {
            amount = balance - accrueInfo.pendingFeeEarned;
        }
    }

    function harvest(uint256, address) external override isActive onlyBentoBox returns (int256) {
        accrue();
        return int256(0);
    }

    function withdraw(uint256 amount) external override isActive onlyBentoBox returns (uint256 actualAmount) {
        accrue();
        uint256 maxAvailableAmount = availableAmount();

        if (maxAvailableAmount > 0) {
            actualAmount = amount > maxAvailableAmount ? maxAvailableAmount : amount;
            maxAvailableAmount -= actualAmount;
            strategyToken.safeTransfer(address(bentoBox), actualAmount);
        }

        principal = maxAvailableAmount;
    }

    function exit(uint256 amount) external override onlyBentoBox returns (int256 amountAdded) {
        accrue();
        uint256 maxAvailableAmount = availableAmount();

        if (maxAvailableAmount > 0) {
            uint256 actualAmount = amount > maxAvailableAmount ? maxAvailableAmount : amount;
            amountAdded = int256(actualAmount) - int256(amount);
            strategyToken.safeTransfer(address(bentoBox), actualAmount);
        }

        principal = 0;
        exited = true;
    }

    function withdrawFee(uint128 amount) external onlyExecutor {
        if (amount > accrueInfo.pendingFeeEarned) {
            revert AmountExceedsPendingFeeEarned(amount);
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
            revert InsupportedToken(tokenOut);
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
        accrueInfo.pendingFeeEarned -= uint128(amountIn);

        tokenOut.safeTransfer(feeTo, amountIn);
        emit SwapAndWithdrawFee(amountIn, amountOut, tokenOut);
    }

    function accrue() public {
        AccrueInfo memory _accrueInfo = accrueInfo;

        // Number of seconds since accrue was called
        uint256 elapsedTime = block.timestamp - _accrueInfo.lastAccrued;
        if (elapsedTime == 0) {
            return;
        }

        _accrueInfo.lastAccrued = uint64(block.timestamp);

        if (principal == 0) {
            accrueInfo = _accrueInfo;
            return;
        }

        // Accrue interest
        uint128 extraAmount = uint128((principal * _accrueInfo.interestPerSecond * elapsedTime) / 1e18);

        _accrueInfo.pendingFeeEarned += extraAmount;
        accrueInfo = _accrueInfo;

        emit LogAccrue(extraAmount);
    }

    function setFeeTo(address _feeTo) external onlyOwner {
        if (_feeTo == address(0)) {
            revert InvalidFeeTo(_feeTo);
        }

        emit FeeToChanged(feeTo, _feeTo);
        feeTo = _feeTo;
    }

    function setSwapper(address _swapper) external onlyOwner {
        strategyToken.approve(swapper, 0);
        strategyToken.approve(_swapper, type(uint256).max);

        emit SwapperChanged(swapper, _swapper);
        swapper = _swapper;
    }

    function setSwapTokenOutEnabled(IERC20 token, bool enabled) external onlyOwner {
        swapTokenOutEnabled[token] = enabled;
        emit SwapTokenOutEnabled(token, enabled);
    }

    function changeInterestRate(uint64 newInterestRate) public onlyOwner {
        uint64 oldInterestRate = accrueInfo.interestPerSecond;

        require(
            newInterestRate < oldInterestRate + (oldInterestRate * 3) / 4 || newInterestRate <= ONE_PERCENT_RATE,
            "Interest rate increase > 75%"
        );
        require(lastInterestUpdate + 3 days < block.timestamp, "Update only every 3 days");

        lastInterestUpdate = block.timestamp;
        accrueInfo.interestPerSecond = newInterestRate;
        emit LogInterestChange(oldInterestRate, newInterestRate);
    }
}
