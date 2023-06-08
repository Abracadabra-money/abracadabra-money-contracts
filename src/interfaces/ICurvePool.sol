// SPDX-License-Identifier: MIT
// solhint-disable func-name-mixedcase, var-name-mixedcase
pragma solidity >=0.8.0;

enum CurvePoolInterfaceType {
    ICURVE_POOL,
    ICURVE_3POOL_ZAPPER,
    IFACTORY_POOL,
    ITRICRYPTO_POOL
}

interface ICurvePool {
    function decimals() external view returns (uint256);

    function coins(uint256 i) external view returns (address);

    function exchange_underlying(int128 i, int128 j, uint256 dx, uint256 min_dy, address receiver) external returns (uint256);

    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy, address receiver) external returns (uint256);

    function exchange(uint256 i, uint256 j, uint256 dx, uint256 min_dy) external returns (uint256);

    function get_dy_underlying(int128 i, int128 j, uint256 dx) external view returns (uint256);

    function get_dy(int128 i, int128 j, uint256 dx) external view returns (uint256);

    function approve(address _spender, uint256 _value) external returns (bool);

    function add_liquidity(uint256[2] memory amounts, uint256 _min_mint_amount) external;

    function add_liquidity(uint256[3] memory amounts, uint256 _min_mint_amount) external;

    function add_liquidity(uint256[4] memory amounts, uint256 _min_mint_amount) external;

    function remove_liquidity_one_coin(uint256 tokenAmount, int128 i, uint256 min_amount) external returns (uint256);

    function get_virtual_price() external view returns (uint256 price);
}

interface ICurve3PoolZapper {
    function add_liquidity(address _pool, uint256[4] memory _deposit_amounts, uint256 _min_mint_amount) external returns (uint256);

    function add_liquidity(
        address _pool,
        uint256[4] memory _deposit_amounts,
        uint256 _min_mint_amount,
        address _receiver
    ) external returns (uint256);

    function remove_liquidity(address _pool, uint256 _burn_amount, uint256[4] memory _min_amounts) external returns (uint256[4] memory);

    function remove_liquidity(
        address _pool,
        uint256 _burn_amount,
        uint256[4] memory _min_amounts,
        address _receiver
    ) external returns (uint256[4] memory);

    function remove_liquidity_one_coin(address _pool, uint256 _burn_amount, int128 i, uint256 _min_amount) external returns (uint256);

    function remove_liquidity_one_coin(
        address _pool,
        uint256 _burn_amount,
        int128 i,
        uint256 _min_amount,
        address _receiver
    ) external returns (uint256);
}

interface IFactoryPool is ICurvePool {
    function remove_liquidity_one_coin(uint256 tokenAmount, uint256 i, uint256 min_amount) external returns (uint256);
}

interface ITriCrypto is ICurvePool {
    function remove_liquidity_one_coin(uint256 tokenAmount, uint256 i, uint256 min_amount) external;
}
