// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Operatable} from "mixins/Operatable.sol";
import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {BoringERC20} from "BoringSolidity/libraries/BoringERC20.sol";
import {IAggregator} from "interfaces/IAggregator.sol";
import {SafeApproveLib} from "libraries/SafeApproveLib.sol";

interface ITriCryptoWithExchange {
    function exchange(uint256 i, uint256 j, uint256 dx, uint256 min_dy) external;

    function last_prices(uint256 i) external view returns (uint256);
}

contract TriCryptoUpdator is Operatable {
    using BoringERC20 for IERC20;
    using SafeApproveLib for IERC20;

    address public tricrypto = 0xD51a44d3FaE010294C616388b506AcdA1bfAAE46;
    IAggregator private WETH_ORACLE = IAggregator(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
    IAggregator private BTC_ORACLE = IAggregator(0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c);

    uint256 private constant TRADE_AMOUNT = 1e5;

    IERC20 constant USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 constant WBTC = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    IERC20 constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    constructor() {
        USDT.safeApprove(tricrypto, type(uint256).max);
        WETH.safeApprove(tricrypto, type(uint256).max);
        WBTC.safeApprove(tricrypto, type(uint256).max);
    }

    function trade() external onlyOperators {
        ITriCryptoWithExchange(tricrypto).exchange(0, 1, TRADE_AMOUNT, 0);
        ITriCryptoWithExchange(tricrypto).exchange(1, 2, WBTC.balanceOf(address(this)), 0);
        ITriCryptoWithExchange(tricrypto).exchange(2, 0, WETH.balanceOf(address(this)), 0);
    }

    function checker() external view returns (bool canExec, bytes memory execPayload) {
        canExec = false;

        uint256 chainLinkPriceBtc = uint256(BTC_ORACLE.latestAnswer());
        uint256 chainLinkPriceEth = uint256(WETH_ORACLE.latestAnswer());

        uint256 curvePriceBTC = ITriCryptoWithExchange(tricrypto).last_prices(0) / 1e12;
        uint256 curvePriceETH = ITriCryptoWithExchange(tricrypto).last_prices(1) / 1e12;

        if (
            curvePriceETH * 95 > chainLinkPriceEth ||
            curvePriceETH * 105 < chainLinkPriceEth ||
            curvePriceBTC * 95 > chainLinkPriceBtc ||
            curvePriceBTC * 105 < chainLinkPriceBtc
        ) {
            canExec = true;
        }

        execPayload = abi.encodeCall(TriCryptoUpdator.trade, ());
    }
}
