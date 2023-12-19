// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface ISolidlyGauge {
    function earned(address token, address account) external view returns (uint256);

    function depositAll(uint256 tokenId) external;

    function deposit(uint256 amount, uint256 tokenId) external;

    function getReward(address account, address[] memory tokens) external;

    function withdrawAll() external;

    function withdraw(uint256 amount) external;

    function balanceOf(address account) external view returns (uint256);

    function notifyRewardAmount(address token, uint256 amount) external;
}

interface ISolidlyPair {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function totalSupply() external view returns (uint256 totalSupply);

    function getAmountOut(uint256 amountIn, address tokenIn) external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function stable() external view returns (bool);

    function metadata() external view returns (uint256 dec0, uint256 dec1, uint256 r0, uint256 r1, bool st, address t0, address t1);

    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;

    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    function token0() external pure returns (address);

    function token1() external pure returns (address);

    function tokens() external view returns (address, address);

    function reserve0() external pure returns (uint256);

    function reserve1() external pure returns (uint256);

    function claimFees() external returns (uint256 claimed0, uint256 claimed1);

    function approve(address spender, uint256 amount) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function burn(address to) external returns (uint256 amount0, uint256 amount1);

    function claimable0(address account) external view returns (uint256);

    function claimable1(address account) external view returns (uint256);

    function supplyIndex0(address account) external view returns (uint256);

    function supplyIndex1(address account) external view returns (uint256);

    function index0() external view returns (uint256);

    function index1() external view returns (uint256);
}

interface ISolidlyRouter {
    struct route {
        address from;
        address to;
        bool stable;
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    function addLiquidityETH(
        address token,
        bool stable,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);

    function factory() external view returns (address);

    function getAmountOut(uint256 amountIn, address tokenIn, address tokenOut) external view returns (uint256 amount, bool stable);

    function getAmountsOut(uint256 amountIn, ISolidlyRouter.route[] memory routes) external view returns (uint256[] memory amounts);

    function getReserves(address tokenA, address tokenB, bool stable) external view returns (uint256 reserveA, uint256 reserveB);

    function isPair(address pair) external view returns (bool);

    function pairFor(address tokenA, address tokenB, bool stable) external view returns (address pair);

    function quoteAddLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint256 amountADesired,
        uint256 amountBDesired
    ) external view returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    function quoteRemoveLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint256 liquidity
    ) external view returns (uint256 amountA, uint256 amountB);

    function removeLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETH(
        address token,
        bool stable,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountETH);

    function removeLiquidityETHWithPermit(
        address token,
        bool stable,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountToken, uint256 amountETH);

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        bool stable,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountA, uint256 amountB);

    function sortTokens(address tokenA, address tokenB) external pure returns (address token0, address token1);

    function swapExactETHForTokens(
        uint256 amountOutMin,
        ISolidlyRouter.route[] memory routes,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        ISolidlyRouter.route[] memory routes,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        ISolidlyRouter.route[] memory routes,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactTokensForTokensSimple(
        uint256 amountIn,
        uint256 amountOutMin,
        address tokenFrom,
        address tokenTo,
        bool stable,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function weth() external view returns (address);
}
