// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/interfaces/IERC20.sol";
import "BoringSolidity/libraries/BoringERC20.sol";
import "interfaces/ILiquityStabilityPool.sol";
import "./BaseStrategy.sol";

contract LiquityStabilityPoolStrategyFrontendTag {
    constructor(ILiquityStabilityPool _pool) {
        _pool.registerFrontEnd(1e18);
    }
}

contract LiquityStabilityPoolStrategy is BaseStrategy {
    using BoringERC20 for IERC20;

    error InvalidFeePercent();
    error InsupportedToken(IERC20 token);
    error SwapFailed();
    error InsufficientAmountOut();

    event FeeChanged(uint256 previousFee, uint256 newFee, address previousFeeCollector, address newFeeCollector);
    event SwapperChanged(address oldSwapper, address newSwapper);
    event RewardSwapped(IERC20 token, uint256 total, uint256 amountOut, uint256 feeAmount);
    event RewardTokenUpdated(IERC20 token, bool enabled);

    ILiquityStabilityPool public immutable pool;
    address public immutable tag;

    address public feeCollector;
    uint8 public feePercent;
    address public swapper;

    mapping(IERC20 => bool) public rewardTokenEnabled;

    constructor(
        IERC20 _strategyToken,
        IBentoBoxV1 _bentoBox,
        ILiquityStabilityPool _pool
    ) BaseStrategy(_strategyToken, _bentoBox) {
        pool = _pool;
        feeCollector = msg.sender;
        IERC20(_strategyToken).approve(address(_pool), type(uint256).max);

        // Register a dummy frontend tag set to 100% since we
        // should be getting all rewards in this contract.
        tag = address(new LiquityStabilityPoolStrategyFrontendTag(_pool));
    }

    /// @dev only allowed to receive eth from the stability pool
    receive() external payable {
        require(msg.sender == address(pool));
    }

    /// @param token The reward token to add, use address(0) for ETH
    function setRewardTokenEnabled(IERC20 token, bool enabled) external onlyOwner {
        rewardTokenEnabled[token] = enabled;
        emit RewardTokenUpdated(token, enabled);
    }

    function _skim(uint256 amount) internal virtual override {
        pool.provideToSP(amount, tag);
    }

    function _harvest(uint256) internal virtual override returns (int256) {
        pool.withdrawFromSP(0);
        return int256(0);
    }

    function _withdraw(uint256 amount) internal virtual override {
        pool.withdrawFromSP(amount);
    }

    function _exit() internal virtual override {
        pool.withdrawFromSP(pool.getCompoundedLUSDDeposit(address(this)));
    }

    function swapRewards(
        uint256 amountOutMin,
        IERC20 rewardToken,
        bytes calldata data
    ) external onlyExecutor returns (uint256 amountOut) {
        if (!rewardTokenEnabled[rewardToken]) {
            revert InsupportedToken(rewardToken);
        }

        uint256 amountBefore = IERC20(strategyToken).balanceOf(address(this));
        uint256 value;

        // use eth reward?
        if (address(rewardToken) == address(0)) {
            value = address(this).balance;
        } else {
            rewardToken.approve(swapper, rewardToken.balanceOf(address(this)));
        }

        (bool success, ) = swapper.call{value: value}(data);
        if (!success) {
            revert SwapFailed();
        }

        uint256 total = IERC20(strategyToken).balanceOf(address(this)) - amountBefore;

        if (total < amountOutMin) {
            revert InsufficientAmountOut();
        }

        uint256 feeAmount = (total * feePercent) / 100;
        if (feeAmount > 0) {
            amountOut = total - feeAmount;
            IERC20(strategyToken).safeTransfer(feeCollector, feeAmount);
        }

        if (address(rewardToken) != address(0)) {
            rewardToken.approve(swapper, 0);
        }

        emit RewardSwapped(rewardToken, total, amountOut, feeAmount);
    }

    function setFeeParameters(address _feeCollector, uint8 _feePercent) external onlyOwner {
        if (feePercent > 100) {
            revert InvalidFeePercent();
        }

        emit FeeChanged(feePercent, _feePercent, feeCollector, _feeCollector);

        feeCollector = _feeCollector;
        feePercent = _feePercent;
    }

    function setSwapper(address _swapper) external onlyOwner {
        emit SwapperChanged(swapper, _swapper);
        swapper = _swapper;
    }

    function resetAllowance() external onlyOwner {
        IERC20(strategyToken).approve(address(pool), type(uint256).max);
    }
}
