// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {Address} from "openzeppelin-contracts/utils/Address.sol";
import {BaseStrategy} from "./BaseStrategy.sol";
import {IBentoBoxV1} from "interfaces/IBentoBoxV1.sol";
import {IStargateLPStaking, IStargatePool, IStargateRouter} from "interfaces/IStargate.sol";
import {FeeCollectable} from "mixins/FeeCollectable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

contract StargateLPStrategy is BaseStrategy, FeeCollectable {
    using SafeTransferLib for address;

    error ErrInsufficientAmountOut();

    event LogLpMinted(uint256 total, uint256 strategyAmount, uint256 feeAmount);
    event LogStargateSwapperChanged(address oldSwapper, address newSwapper);

    IStargateLPStaking public immutable staking;
    IStargateRouter public immutable router;
    address public immutable rewardToken;
    address public immutable underlyingToken;

    uint256 public immutable poolId;
    uint256 public immutable pid;
    address public stargateSwapper;

    constructor(
        IStargatePool _strategyToken,
        IBentoBoxV1 _bentoBox,
        IStargateRouter _router,
        IStargateLPStaking _staking,
        address _rewardToken,
        uint256 _pid
    ) BaseStrategy(IERC20(address(_strategyToken)), _bentoBox) {
        router = _router;
        staking = _staking;
        rewardToken = _rewardToken;
        pid = _pid;

        poolId = IStargatePool(address(_strategyToken)).poolId();
        address _underlyingToken = IStargatePool(address(_strategyToken)).token();

        feeBips = 150; // 1.5%
        feeCollector = msg.sender;

        IERC20(_underlyingToken).approve(address(_router), type(uint256).max);
        underlyingToken = _underlyingToken;

        IERC20(address(_strategyToken)).approve(address(_staking), type(uint256).max);
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

        // rewardToken -> Pool underlying Token (USDT, USDC...)
        Address.functionCall(stargateSwapper, data);

        // Pool underlying Token in this contract
        uint256 underlyingTokenAmount = underlyingToken.balanceOf(address(this));

        // Underlying Token -> Stargate Pool LP
        router.addLiquidity(poolId, underlyingTokenAmount, address(this));

        uint256 total = IERC20(strategyToken).balanceOf(address(this)) - amountStrategyLpBefore;

        if (total < amountOutMin) {
            revert ErrInsufficientAmountOut();
        }

        uint256 feeAmount;
        (amountOut, feeAmount) = calculateFees(total);

        address(strategyToken).safeTransfer(feeCollector, feeAmount);

        emit LogLpMinted(total, amountOut, feeAmount);
    }

    function setStargateSwapper(address _stargateSwapper) external onlyOwner {
        address previousStargateSwapper = address(stargateSwapper);

        if (previousStargateSwapper != address(0)) {
            rewardToken.safeApprove(previousStargateSwapper, 0);
        }

        stargateSwapper = _stargateSwapper;

        if (_stargateSwapper != address(0)) {
            rewardToken.safeApprove(_stargateSwapper, type(uint256).max);
        }

        emit LogStargateSwapperChanged(previousStargateSwapper, _stargateSwapper);
    }

    function isFeeOperator(address account) public view override returns (bool) {
        return account == owner;
    }
}
