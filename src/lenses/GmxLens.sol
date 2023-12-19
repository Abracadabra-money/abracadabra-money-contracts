// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {MathLib} from "libraries/MathLib.sol";
import {IGmxVault, IGmxGlpManager, IVaultPriceFeed} from "interfaces/IGmxV1.sol";

contract GmxLens {
    uint256 private constant BASIS_POINTS_DIVISOR = 10000;
    uint256 private constant PRICE_PRECISION = 10 ** 30;
    uint256 private constant USDG_DECIMALS = 18;
    uint256 private constant PRECISION = 10 ** 18;

    struct TokenFee {
        address token;
        uint256 fee;
    }

    IGmxGlpManager public immutable manager;
    IGmxVault public immutable vault;

    IERC20 private immutable glp;
    IERC20 private immutable usdg;

    constructor(IGmxGlpManager _manager, IGmxVault _vault) {
        manager = _manager;
        vault = _vault;
        glp = IERC20(manager.glp());
        usdg = IERC20(manager.usdg());
    }

    function getGlpPrice() public view returns (uint256) {
        return (manager.getAumInUsdg(false) * PRICE_PRECISION) / glp.totalSupply();
    }

    function getTokenOutFromBurningGlp(address tokenOut, uint256 glpAmount) public view returns (uint256 amount, uint256 feeBasisPoints) {
        uint256 usdgAmount = (glpAmount * getGlpPrice()) / PRICE_PRECISION;

        feeBasisPoints = _getFeeBasisPoints(
            tokenOut,
            vault.usdgAmounts(tokenOut) - usdgAmount,
            usdgAmount,
            vault.mintBurnFeeBasisPoints(),
            vault.taxBasisPoints(),
            false
        );

        uint256 redemptionAmount = _getRedemptionAmount(tokenOut, usdgAmount);
        amount = _collectSwapFees(redemptionAmount, feeBasisPoints);
    }

    function getMaxAmountIn(IERC20 tokenIn) public view returns (uint256 amount) {
        amount = MathLib.subWithZeroFloor(vault.maxUsdgAmounts(address(tokenIn)), vault.usdgAmounts(address(tokenIn)));
    }

    function getMintedGlpFromTokenIn(address tokenIn, uint256 amount) public view returns (uint256 amountOut, uint256 feeBasisPoints) {
        uint256 aumInUsdg = manager.getAumInUsdg(true);
        uint256 usdgAmount;
        (usdgAmount, feeBasisPoints) = _simulateBuyUSDG(tokenIn, amount);

        amountOut = (aumInUsdg == 0 ? usdgAmount : ((usdgAmount * PRICE_PRECISION) / getGlpPrice()));
    }

    function getUsdgAmountFromTokenIn(address tokenIn, uint256 tokenAmount) public view returns (uint256 usdgAmount) {
        uint256 price = vault.getMinPrice(tokenIn);
        uint256 rawUsdgAmount = (tokenAmount * price) / PRICE_PRECISION;
        return vault.adjustForDecimals(rawUsdgAmount, tokenIn, address(usdg));
    }

    function _simulateBuyUSDG(address tokenIn, uint256 tokenAmount) private view returns (uint256 mintAmount, uint256 feeBasisPoints) {
        uint256 usdgAmount = getUsdgAmountFromTokenIn(tokenIn, tokenAmount);

        feeBasisPoints = _getFeeBasisPoints(
            tokenIn,
            vault.usdgAmounts(tokenIn),
            usdgAmount,
            vault.mintBurnFeeBasisPoints(),
            vault.taxBasisPoints(),
            true
        );

        uint256 amountAfterFees = _collectSwapFees(tokenAmount, feeBasisPoints);
        mintAmount = getUsdgAmountFromTokenIn(tokenIn, amountAfterFees);
    }

    function _collectSwapFees(uint256 _amount, uint256 _feeBasisPoints) private pure returns (uint256) {
        return (_amount * (BASIS_POINTS_DIVISOR - _feeBasisPoints)) / BASIS_POINTS_DIVISOR;
    }

    function _getFeeBasisPoints(
        address _token,
        uint256 tokenUsdgAmount,
        uint256 _usdgDelta,
        uint256 _feeBasisPoints,
        uint256 _taxBasisPoints,
        bool _increment
    ) private view returns (uint256) {
        if (!vault.hasDynamicFees()) {
            return _feeBasisPoints;
        }

        uint256 initialAmount = tokenUsdgAmount;
        uint256 nextAmount = initialAmount + _usdgDelta;
        if (!_increment) {
            nextAmount = _usdgDelta > initialAmount ? 0 : initialAmount - _usdgDelta;
        }

        uint256 targetAmount = _getTargetUsdgAmount(_token);
        if (targetAmount == 0) {
            return _feeBasisPoints;
        }

        uint256 initialDiff = initialAmount > targetAmount ? initialAmount - targetAmount : targetAmount - initialAmount;
        uint256 nextDiff = nextAmount > targetAmount ? nextAmount - targetAmount : targetAmount - nextAmount;

        if (nextDiff < initialDiff) {
            uint256 rebateBps = (_taxBasisPoints * initialDiff) / targetAmount;
            return rebateBps > _feeBasisPoints ? 0 : _feeBasisPoints - rebateBps;
        }

        uint256 averageDiff = (initialDiff + nextDiff) / 2;
        if (averageDiff > targetAmount) {
            averageDiff = targetAmount;
        }
        uint256 taxBps = (_taxBasisPoints * averageDiff) / targetAmount;
        return _feeBasisPoints + taxBps;
    }

    function _getTargetUsdgAmount(address _token) private view returns (uint256) {
        uint256 supply = IERC20(usdg).totalSupply();

        if (supply == 0) {
            return 0;
        }
        uint256 weight = vault.tokenWeights(_token);
        return (weight * supply) / vault.totalTokenWeights();
    }

    function _decreaseUsdgAmount(address _token, uint256 _amount) private view returns (uint256) {
        uint256 value = vault.usdgAmounts(_token);
        if (value <= _amount) {
            return 0;
        }
        return value - _amount;
    }

    function _getRedemptionAmount(address _token, uint256 _usdgAmount) private view returns (uint256) {
        uint256 price = _getMaxPrice(_token);
        uint256 redemptionAmount = (_usdgAmount * PRICE_PRECISION) / price;

        return _adjustForDecimals(redemptionAmount, address(usdg), _token);
    }

    function _adjustForDecimals(uint256 _amount, address _tokenDiv, address _tokenMul) private view returns (uint256) {
        uint256 decimalsDiv = _tokenDiv == address(usdg) ? USDG_DECIMALS : vault.tokenDecimals(_tokenDiv);
        uint256 decimalsMul = _tokenMul == address(usdg) ? USDG_DECIMALS : vault.tokenDecimals(_tokenMul);

        return (_amount * 10 ** decimalsMul) / 10 ** decimalsDiv;
    }

    function _getMaxPrice(address _token) private view returns (uint256) {
        return IVaultPriceFeed(vault.priceFeed()).getPrice(_token, true, false, true);
    }
}
