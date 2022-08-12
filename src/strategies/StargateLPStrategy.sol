// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/interfaces/IERC20.sol";
import "libraries/SafeTransferLib.sol";

import "./BaseStrategy.sol";
import "interfaces/IBentoBoxV1.sol";
import "interfaces/IStargateLPStaking.sol";
import "interfaces/IStargatePool.sol";
import "interfaces/IStargateRouter.sol";

contract StargateLPStrategy is BaseStrategy {
    using SafeTransferLib for IERC20;

    event LpMinted(uint256 total, uint256 strategyAmount, uint256 feeAmount);
    event FeeParametersChanged(address feeCollector, uint256 feeAmount);
    event StargateSwapperChanged(address oldSwapper, address newSwapper);

    IStargateLPStaking public immutable staking;
    IStargateRouter public immutable router;
    IERC20 public immutable rewardToken;
    IERC20 public immutable underlyingToken;

    uint256 public immutable poolId;
    uint256 public immutable pid;

    address public feeCollector;
    uint8 public feePercent;
    address public stargateSwapper;

    constructor(
        IStargatePool _strategyToken,
        IBentoBoxV1 _bentoBox,
        IStargateRouter _router,
        IStargateLPStaking _staking,
        IERC20 _rewardToken,
        uint256 _pid
    ) BaseStrategy(IERC20(address(_strategyToken)), _bentoBox, address(0), address(0), "") {
        router = _router;
        staking = _staking;
        rewardToken = _rewardToken;
        pid = _pid;

        poolId = IStargatePool(address(_strategyToken)).poolId();
        IERC20 _underlyingToken = IERC20(IStargatePool(address(_strategyToken)).token());

        feePercent = 10;
        feeCollector = msg.sender;

        _underlyingToken.safeApprove(address(_router), type(uint256).max);
        underlyingToken = _underlyingToken;

        IERC20(address(_strategyToken)).safeApprove(address(_staking), type(uint256).max);
    }

    function _skim(uint256 amount) internal override {
        staking.deposit(pid, amount);
    }

    function _harvest(uint256) internal override returns (int256) {
        staking.withdraw(pid, 0);
        return int256(0);
    }

    function _withdraw(uint256 amount) internal override {
        staking.withdraw(pid, amount);
    }

    function _exit() internal override {
        staking.emergencyWithdraw(pid);
    }

    function swapToLP(uint256 amountOutMin, bytes calldata data) public onlyExecutor returns (uint256 amountOut) {
        // Current Stargate LP Amount
        uint256 amountStrategyLpBefore = IERC20(strategyToken).balanceOf(address(this));

        // STG -> Pool underlying Token (USDT, USDC...)
        (bool success, ) = stargateSwapper.call(data);
        require(success, "swap failed");

        // Pool underlying Token in this contract
        uint256 underlyingTokenAmount = underlyingToken.balanceOf(address(this));

        // Underlying Token -> Stargate Pool LP
        router.addLiquidity(poolId, underlyingTokenAmount, address(this));

        uint256 total = IERC20(strategyToken).balanceOf(address(this)) - amountStrategyLpBefore;

        require(total >= amountOutMin, "amountOutMin not met");

        uint256 feeAmount = (total * feePercent) / 100;
        amountOut = total - feeAmount;
        IERC20(strategyToken).safeTransfer(feeCollector, feeAmount);

        emit LpMinted(total, amountOut, feeAmount);
    }

    function setFeeParameters(address _feeCollector, uint8 _feePercent) external onlyOwner {
        require(feePercent <= 100, "invalid feePercent");
        feeCollector = _feeCollector;
        feePercent = _feePercent;

        emit FeeParametersChanged(_feeCollector, _feePercent);
    }

    function setStargateSwapper(address _stargateSwapper) external onlyOwner {
        address previousStargateSwapper = address(stargateSwapper);

        if (previousStargateSwapper != address(0)) {
            rewardToken.approve(previousStargateSwapper, 0);
        }

        stargateSwapper = _stargateSwapper;

        if (_stargateSwapper != address(0)) {
            rewardToken.approve(_stargateSwapper, type(uint256).max);
        }

        emit StargateSwapperChanged(previousStargateSwapper, _stargateSwapper);
    }
}
