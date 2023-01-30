// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface CurvePool {
    function exchange_underlying(int128 i, int128 j, uint256 dx, uint256 min_dy, address receiver) external returns (uint256);
    function approve(address _spender, uint256 _value) external returns (bool);
    function remove_liquidity_one_coin(uint256 tokenAmount, uint256 i, uint256 min_amount) external;
    function add_liquidity(uint256[3] memory amounts, uint256 _min_mint_amount) external;
}