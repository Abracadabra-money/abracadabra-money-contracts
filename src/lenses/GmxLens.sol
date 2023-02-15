// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/interfaces/IERC20.sol";
import "interfaces/IGmxVault.sol";
import "interfaces/IGmxGlpManager.sol";
import "interfaces/IGmxVaultPriceFeed.sol";

contract GmxLens {
    uint256 private constant BASIS_POINTS_DIVISOR = 10000;
    uint256 private constant PRICE_PRECISION = 10**30;
    uint256 private constant USDG_DECIMALS = 18;

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

    function getTokenOutFromBurningGlp(address tokenOut, uint256 glpAmount) external view returns (uint256) {
        uint256 aumInUsdg = manager.getAumInUsdg(false);
        uint256 glpSupply = glp.totalSupply();
        uint256 initialAmount = (glpAmount * aumInUsdg) / glpSupply;
        uint256 redemptionAmount = _getRedemptionAmount(tokenOut, initialAmount);

        uint256 usdgAmount = _decreaseUsdgAmount(tokenOut, initialAmount);

        uint256 feeBasisPoints = _getFeeBasisPoints(
            tokenOut,
            usdgAmount,
            initialAmount,
            vault.mintBurnFeeBasisPoints(),
            vault.taxBasisPoints(),
            false
        );

        return _collectSwapFees(redemptionAmount, feeBasisPoints);
    }

    function getMintedGlpFromTokenIn(address tokenIn, uint256 amount) external view returns (uint256) {
        uint256 aumInUsdg = manager.getAumInUsdg(true);
        uint256 glpSupply = IERC20(glp).totalSupply();
        uint256 usdgAmount = _simulateBuyUSDG(tokenIn, amount);

        return aumInUsdg == 0 ? usdgAmount : (usdgAmount * glpSupply) / aumInUsdg;
    }

    function _simulateBuyUSDG(address tokenIn, uint256 tokenAmount) private view returns (uint256) {
        uint256 price = vault.getMinPrice(tokenIn);
        uint256 usdgAmount = (tokenAmount * price) / PRICE_PRECISION;
        usdgAmount = vault.adjustForDecimals(usdgAmount, tokenIn, address(usdg));

        uint256 feeBasisPoints = _getFeeBasisPoints(
            tokenIn,
            vault.usdgAmounts(tokenIn),
            usdgAmount,
            vault.mintBurnFeeBasisPoints(),
            vault.taxBasisPoints(),
            true
        );
        uint256 amountAfterFees = _collectSwapFees(tokenAmount, feeBasisPoints);
        uint256 mintAmount = (amountAfterFees * price) / PRICE_PRECISION;
        return vault.adjustForDecimals(mintAmount, tokenIn, address(usdg));
    }

    function _collectSwapFees(uint256 _amount, uint256 _feeBasisPoints) private pure returns (uint256) {
        return (_amount * (BASIS_POINTS_DIVISOR - _feeBasisPoints)) / BASIS_POINTS_DIVISOR;
    }

    function _getFeeBasisPoints(
        address _token,
        uint256 _initialAmount,
        uint256 _usdgDelta,
        uint256 _feeBasisPoints,
        uint256 _taxBasisPoints,
        bool _increment
    ) private view returns (uint256) {
        if (!vault.hasDynamicFees()) {
            return _feeBasisPoints;
        }
        uint256 nextAmount = _initialAmount + _usdgDelta;
        if (!_increment) {
            nextAmount = _usdgDelta > _initialAmount ? 0 : _initialAmount - _usdgDelta;
        }

        uint256 targetAmount = _getTargetUsdgAmount(_token);
        if (targetAmount == 0) {
            return _feeBasisPoints;
        }

        uint256 initialDiff = _initialAmount > targetAmount ? _initialAmount - targetAmount : targetAmount - _initialAmount;
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

    function _adjustForDecimals(
        uint256 _amount,
        address _tokenDiv,
        address _tokenMul
    ) private view returns (uint256) {
        uint256 decimalsDiv = _tokenDiv == address(usdg) ? USDG_DECIMALS : vault.tokenDecimals(_tokenDiv);
        uint256 decimalsMul = _tokenMul == address(usdg) ? USDG_DECIMALS : vault.tokenDecimals(_tokenMul);
        return (_amount * 10**decimalsMul) / 10**decimalsDiv;
    }

    function _getMaxPrice(address _token) private view returns (uint256) {
        return IVaultPriceFeed(vault.priceFeed()).getPrice(_token, true, false, true);
    }
}
