// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IBentoBoxV1} from "interfaces/IBentoBoxV1.sol";
import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {BoringERC20} from "BoringSolidity/libraries/BoringERC20.sol";
import {UniswapV2Library, UniswapV2OneSided} from "libraries/UniswapV2Lib.sol";
import {IUniswapV2Pair, IUniswapV2Router01} from "interfaces/IUniswapV2.sol";
import {BaseStrategy} from "./BaseStrategy.sol";

interface IMasterChef {
    function deposit(uint256 _pid, uint256 _amount) external;

    function withdraw(uint256 _pid, uint256 _amount) external;

    function userInfo(uint256 _pid, address user) external view returns (uint256 amount, uint256 rewardDebt);

    function emergencyWithdraw(uint256 _pid) external;
}

contract MasterChefLPStrategy is BaseStrategy {
    using BoringERC20 for IERC20;

    error InvalidFeePercent();
    error InsupportedToken(address token);
    event LpMinted(uint256 total, uint256 strategyAmount, uint256 feeAmount);
    event RewardTokenUpdated(address token, bool enabled);
    event FeeChanged(uint256 previousFee, uint256 newFee, address previousFeeCollector, address newFeeCollector);

    IMasterChef public immutable masterchef;
    IUniswapV2Router01 public immutable router;
    uint256 public immutable pid;
    address public immutable token0;
    address public immutable token1;
    bytes32 internal immutable pairCodeHash;
    address public immutable factory;

    struct RewardTokenInfo {
        bool enabled;
        // When true, the _rewardToken will be swapped to the pair's token0 for one-sided liquidity providing, otherwise, the pair's token1.
        bool usePairToken0;
    }

    mapping(address => RewardTokenInfo) public rewardTokensInfo;

    address public feeCollector;
    uint8 public feePercent;

    constructor(
        IERC20 _strategyToken,
        IBentoBoxV1 _bentoBox,
        address _factory,
        IMasterChef _masterchef,
        uint256 _pid,
        IUniswapV2Router01 _router,
        bytes32 _pairCodeHash
    ) BaseStrategy(_strategyToken, _bentoBox) {
        factory = _factory;
        masterchef = _masterchef;
        pid = _pid;
        router = _router;
        pairCodeHash = _pairCodeHash;
        feeCollector = msg.sender;

        address _token0 = IUniswapV2Pair(address(_strategyToken)).token0();
        address _token1 = IUniswapV2Pair(address(_strategyToken)).token1();

        IERC20(_token0).approve(address(_router), type(uint256).max);
        IERC20(_token1).approve(address(_router), type(uint256).max);
        IERC20(_strategyToken).approve(address(_masterchef), type(uint256).max);

        token0 = _token0;
        token1 = _token1;
    }

    /// @param token The reward token to add
    /// @param usePairToken0 When true, the _rewardToken will be swapped to the pair's token0 for one-sided liquidity
    /// providing, otherwise, the pair's token1.
    function setRewardTokenInfo(address token, bool usePairToken0, bool enabled) external onlyOwner {
        rewardTokensInfo[token] = RewardTokenInfo(enabled, usePairToken0);
        emit RewardTokenUpdated(token, enabled);
    }

    function _skim(uint256 amount) internal virtual override {
        masterchef.deposit(pid, amount);
    }

    function _harvest(uint256) internal virtual override returns (int256) {
        masterchef.withdraw(pid, 0);
        return int256(0);
    }

    function _withdraw(uint256 amount) internal virtual override {
        masterchef.withdraw(pid, amount);
    }

    function _exit() internal virtual override {
        masterchef.emergencyWithdraw(pid);
    }

    function _swapRewards(address tokenIn, address tokenOut) private returns (uint256 amountOut) {
        uint256 amountIn = IERC20(tokenIn).balanceOf(address(this));
        IUniswapV2Pair pair = IUniswapV2Pair(address(UniswapV2Library.pairFor(factory, tokenIn, tokenOut, pairCodeHash)));
        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
        IERC20(tokenIn).safeTransfer(address(pair), amountIn);

        if (tokenIn == pair.token0()) {
            amountOut = UniswapV2Library.getAmountOut(amountIn, reserve0, reserve1);
            pair.swap(0, amountOut, address(this), "");
        } else {
            amountOut = UniswapV2Library.getAmountOut(amountIn, reserve1, reserve0);
            pair.swap(amountOut, 0, address(this), "");
        }
    }

    /// @notice Swap some tokens in the contract for the underlying and deposits them to address(this)
    function swapToLP(uint256 amountOutMin, address rewardToken) public onlyExecutor returns (uint256 amountOut) {
        RewardTokenInfo memory info = rewardTokensInfo[rewardToken];
        if (!info.enabled) {
            revert InsupportedToken(rewardToken);
        }

        address pairInputToken = info.usePairToken0 ? token0 : token1;
        uint256 tokenInAmount = _swapRewards(rewardToken, pairInputToken);
        uint256 amountStrategyLpBefore = strategyToken.balanceOf(address(this));
        (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(address(strategyToken)).getReserves();

        UniswapV2OneSided.AddLiquidityFromSingleTokenParams memory _addLiquidityFromSingleTokenParams = UniswapV2OneSided
            .AddLiquidityFromSingleTokenParams(
                router,
                IUniswapV2Pair(address(strategyToken)),
                token0,
                token1,
                reserve0,
                reserve1,
                pairInputToken,
                tokenInAmount,
                address(this)
            );

        UniswapV2OneSided.addLiquidityFromSingleToken(_addLiquidityFromSingleTokenParams);

        uint256 total = IERC20(strategyToken).balanceOf(address(this)) - amountStrategyLpBefore;
        require(total >= amountOutMin, "InsufficientAmountOut");
        uint256 feeAmount = (total * feePercent) / 100;
        if (feeAmount > 0) {
            amountOut = total - feeAmount;
            IERC20(strategyToken).safeTransfer(feeCollector, feeAmount);
        }

        emit LpMinted(total, amountOut, feeAmount);
    }

    function setFeeParameters(address _feeCollector, uint8 _feePercent) external onlyOwner {
        if (feePercent > 100) {
            revert InvalidFeePercent();
        }

        uint256 previousFee = feePercent;
        address previousFeeCollector = feeCollector;

        feeCollector = _feeCollector;
        feePercent = _feePercent;

        emit FeeChanged(previousFee, _feePercent, previousFeeCollector, _feeCollector);
    }
}
