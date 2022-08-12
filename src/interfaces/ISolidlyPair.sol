// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface ISolidlyPair {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function getAmountOut(uint256 amountIn, address tokenIn) external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;

    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );

    function token0() external pure returns (address);

    function token1() external pure returns (address);

    function tokens() external view returns (address, address);

    function reserve0() external pure returns (uint256);

    function reserve1() external pure returns (uint256);

    function claimFees() external returns (uint256 claimed0, uint256 claimed1);

    function approve(address spender, uint256 amount) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function burn(address to) external returns (uint256 amount0, uint256 amount1);
}
