// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/ERC20.sol";
import "libraries/SafeTransferLib.sol";

import "./BaseStrategy.sol";
import "interfaces/IBentoBoxV1.sol";
import "interfaces/IStargateLPStaking.sol";
import "interfaces/IStargatePool.sol";
import "interfaces/IStargateRouter.sol";

contract StargateLPStrategy is BaseStrategy {
    using SafeTransferLib for ERC20;

    event LpMinted(uint256 total, uint256 strategyAmount, uint256 feeAmount);
    event FeeParametersChanged(address feeCollector, uint256 feeAmount);
    event StargateSwapperChanged(address oldSwapper, address newSwapper);

    IStargateLPStaking public immutable staking;
    IStargateRouter public immutable router;
    ERC20 public immutable rewardToken;
    ERC20 public immutable underlyingToken;

    uint256 public immutable poolId;
    uint256 public immutable pid;

    address public feeCollector;
    uint8 public feePercent;
    address public stargateSwapper;

    constructor(
        ERC20 _strategyToken,
        IBentoBoxV1 _bentoBox,
        IStargateRouter _router,
        IStargateLPStaking _staking,
        ERC20 _rewardToken,
        uint256 _pid
    ) BaseStrategy(_strategyToken, _bentoBox, address(0), address(0), "") {
        router = _router;
        staking = _staking;
        rewardToken = _rewardToken;
        pid = _pid;

        poolId = IStargatePool(address(_strategyToken)).poolId();
        ERC20 _underlyingToken = ERC20(IStargatePool(address(_strategyToken)).token());

        feePercent = 10;
        feeCollector = msg.sender;

        _underlyingToken.safeApprove(address(_router), type(uint256).max);
        underlyingToken = _underlyingToken;

        ERC20(_strategyToken).safeApprove(address(_staking), type(uint256).max);
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
        uint256 amountStrategyLpBefore = ERC20(strategyToken).balanceOf(address(this));

        // STG -> Pool underlying Token (USDT, USDC...)
        (bool success, ) = stargateSwapper.call(data);
        require(success, "swap failed");

        // Pool underlying Token in this contract
        uint256 underlyingTokenAmount = underlyingToken.balanceOf(address(this));

        // Underlying Token -> Stargate Pool LP
        router.addLiquidity(poolId, underlyingTokenAmount, address(this));

        uint256 total = ERC20(strategyToken).balanceOf(address(this)) - amountStrategyLpBefore;

        require(total >= amountOutMin, "amountOutMin not met");

        uint256 feeAmount = (total * feePercent) / 100;
        amountOut = total - feeAmount;
        ERC20(strategyToken).transfer(feeCollector, feeAmount);

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
