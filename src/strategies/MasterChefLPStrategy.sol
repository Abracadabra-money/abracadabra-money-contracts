// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/interfaces/IERC20.sol";
import "BoringSolidity/libraries/BoringERC20.sol";
import "interfaces/IUniswapV2Pair.sol";
import "interfaces/IUniswapV2Router01.sol";
import "libraries/Babylonian.sol";
import "./BaseStrategy.sol";

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

    IUniswapV2Router01 public immutable router;
    IMasterChef public immutable masterchef;
    uint256 public immutable pid;
    address public immutable token0;
    address public immutable token1;

    struct RewardTokenInfo {
        bool enabled;
        // When true, the _rewardToken will be swapped to the pair's token0 for one-sided liquidity providing, otherwise, the pair's token1.
        bool usePairToken0;
        // An intermediary token for swapping any rewards into it before swapping it to _inputPairToken
        address bridgeToken;
    }

    mapping(address => RewardTokenInfo) public rewardTokensInfo;

    address public feeCollector;
    uint8 public feePercent;

    /** @param _strategyToken Address of the underlying LP token the strategy invests.
        @param _bentoBox BentoBox address.
        @param _factory SushiSwap factory.
        @param _pairCodeHash This hash is used to calculate the address of a uniswap-like pool
                                by providing only the addresses of the two IERC20 tokens.
    */
    constructor(
        IERC20 _strategyToken,
        IBentoBoxV1 _bentoBox,
        address _factory,
        IMasterChef _masterchef,
        uint256 _pid,
        IUniswapV2Router01 _router,
        bytes32 _pairCodeHash
    ) BaseStrategy(_strategyToken, _bentoBox, _factory, address(0), _pairCodeHash) {
        masterchef = _masterchef;
        pid = _pid;
        router = _router;
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
    /// @param bridgeToken The token to swap the reward token into because swapping to the lp input token for minting
    /// @param usePairToken0 When true, the _rewardToken will be swapped to the pair's token0 for one-sided liquidity
    /// providing, otherwise, the pair's token1.
    function setRewardTokenInfo(
        address token,
        address bridgeToken,
        bool usePairToken0,
        bool enabled
    ) external onlyOwner {
        rewardTokensInfo[token] = RewardTokenInfo(enabled, usePairToken0, bridgeToken);
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

    function _swapTokens(address tokenIn, address tokenOut) private returns (uint256 amountOut) {
        bool useBridge = bridgeToken != address(0);
        address[] memory path = new address[](useBridge ? 3 : 2);

        path[0] = tokenIn;

        if (useBridge) {
            path[1] = bridgeToken;
        }

        path[path.length - 1] = tokenOut;

        uint256 amountIn = IERC20(path[0]).balanceOf(address(this));
        uint256[] memory amounts = UniswapV2Library.getAmountsOut(factory, amountIn, path, pairCodeHash);
        amountOut = amounts[amounts.length - 1];

        IERC20(path[0]).safeTransfer(UniswapV2Library.pairFor(factory, path[0], path[1], pairCodeHash), amounts[0]);
        _swap(amounts, path, address(this));
    }

    function _calculateSwapInAmount(uint256 reserveIn, uint256 userIn) internal virtual pure returns (uint256) {
        return (Babylonian.sqrt(reserveIn * ((userIn * 3988000) + (reserveIn * 3988009))) - (reserveIn * 1997)) / 1994;
    }

    /// @notice Swap some tokens in the contract for the underlying and deposits them to address(this)
    function swapToLP(uint256 amountOutMin, address rewardToken) public onlyExecutor returns (uint256 amountOut) {
        RewardTokenInfo memory info = rewardTokensInfo[rewardToken];
        if (!info.enabled) {
            revert InsupportedToken(rewardToken);
        }

        address pairInputToken = info.usePairToken0 ? token0 : token1;

        uint256 tokenInAmount = _swapTokens(rewardToken, pairInputToken);
        (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(address(strategyToken)).getReserves();

        // The pairInputToken amount to swap to get the equivalent pair second token amount
        uint256 swapAmountIn = _calculateSwapInAmount(info.usePairToken0 ? reserve0 : reserve1, tokenInAmount);

        address[] memory path = new address[](2);
        if (info.usePairToken0) {
            path[0] = token0;
            path[1] = token1;
        } else {
            path[0] = token1;
            path[1] = token0;
        }

        uint256[] memory amounts = UniswapV2Library.getAmountsOut(factory, swapAmountIn, path, pairCodeHash);

        IERC20(path[0]).safeTransfer(address(strategyToken), amounts[0]);
        _swap(amounts, path, address(this));

        uint256 amountStrategyLpBefore = strategyToken.balanceOf(address(this));

        // Minting liquidity with optimal token balances but is still leaving some
        // dust because of rounding. The dust will be used the next time the function
        // is called.
        router.addLiquidity(
            token0,
            token1,
            IERC20(token0).balanceOf(address(this)),
            IERC20(token1).balanceOf(address(this)),
            1,
            1,
            address(this),
            type(uint256).max
        );

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
