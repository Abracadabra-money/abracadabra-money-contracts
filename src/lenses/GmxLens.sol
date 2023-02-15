// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/interfaces/IERC20.sol";
import "interfaces/IGmxVault.sol";
import "interfaces/IGmxGlpManager.sol";
import "interfaces/IGmxPositionManager.sol";
import "interfaces/IGmxVaultReader.sol";
import "interfaces/IGmxReader.sol";

interface IVaultPriceFeed {
    function adjustmentBasisPoints(address _token) external view returns (uint256);

    function isAdjustmentAdditive(address _token) external view returns (bool);

    function setAdjustment(address _token, bool _isAdditive, uint256 _adjustmentBps) external;

    function setUseV2Pricing(bool _useV2Pricing) external;

    function setIsAmmEnabled(bool _isEnabled) external;

    function setIsSecondaryPriceEnabled(bool _isEnabled) external;

    function setSpreadBasisPoints(address _token, uint256 _spreadBasisPoints) external;

    function setSpreadThresholdBasisPoints(uint256 _spreadThresholdBasisPoints) external;

    function setFavorPrimaryPrice(bool _favorPrimaryPrice) external;

    function setPriceSampleSpace(uint256 _priceSampleSpace) external;

    function setMaxStrictPriceDeviation(uint256 _maxStrictPriceDeviation) external;

    function getPrice(address _token, bool _maximise, bool _includeAmmPrice, bool _useSwapPricing) external view returns (uint256);

    function getAmmPrice(address _token) external view returns (uint256);
}

contract GmxLens {
    uint256 private constant BASIS_POINTS_DIVISOR = 10000;
    uint256 private constant PRICE_PRECISION = 10 ** 30;
    uint256 private constant USDG_DECIMALS = 18;
    uint256 private constant PRECISION = 10 ** 18;

    struct TokenInfo {
        uint256 poolAmount;
        uint256 reservedAmount;
        uint256 availableAmount;
        uint256 usdgAmount;
        uint256 redemptionAmount;
        uint256 weight;
        uint256 bufferAmount;
        uint256 maxUsdgAmount;
        uint256 globalShortSize;
        uint256 maxGlobalShortSize;
        uint256 maxGlobalLongSize;
        uint256 minPrice;
        uint256 maxPrice;
        uint256 guaranteedUsd;
        uint256 maxPrimaryPrice;
        uint256 minPrimaryPrice;
    }

    struct TokenFee {
        address token;
        uint256 fee;
    }

    IGmxGlpManager public immutable manager;
    IGmxVault public immutable vault;
    IGmxVaultReader public immutable vaultReader;
    IGmxPositionManager public immutable positionManager;
    IERC20 public immutable nativeToken;

    IERC20 private immutable glp;
    IERC20 private immutable usdg;

    constructor(
        IGmxGlpManager _manager,
        IGmxVault _vault,
        IGmxVaultReader _vaultReader,
        IGmxPositionManager _positionManager,
        IERC20 _nativeToken
    ) {
        manager = _manager;
        vault = _vault;
        vaultReader = _vaultReader;
        positionManager = _positionManager;
        nativeToken = _nativeToken;
        glp = IERC20(manager.glp());
        usdg = IERC20(manager.usdg());
    }

    function getGlpPrice() public view returns (uint256) {
        return (manager.getAumInUsdg(false) * PRICE_PRECISION) / glp.totalSupply();
    }

    function getTokenInfo(address token) public view returns (TokenInfo memory) {
        address[] memory vaultTokens = new address[](1);
        vaultTokens[0] = token;

        uint256[] memory result = vaultReader.getVaultTokenInfoV4(
            address(vault),
            address(positionManager),
            address(nativeToken),
            1e18,
            vaultTokens
        );
        return
            TokenInfo({
                poolAmount: result[0],
                reservedAmount: result[1],
                availableAmount: result[0] - result[1],
                usdgAmount: result[2],
                redemptionAmount: result[3],
                weight: result[4],
                bufferAmount: result[5],
                maxUsdgAmount: result[6],
                globalShortSize: result[7],
                maxGlobalShortSize: result[8],
                maxGlobalLongSize: result[9],
                minPrice: result[10],
                maxPrice: result[11],
                guaranteedUsd: result[12],
                maxPrimaryPrice: result[13],
                minPrimaryPrice: result[14]
            });
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

    function getMintedGlpFromTokenIn(address tokenIn, uint256 amount) external view returns (uint256, uint256) {
        uint256 aumInUsdg = manager.getAumInUsdg(true);
        (uint256 usdgAmount, uint256 feeBasisPoints) = _simulateBuyUSDG(tokenIn, amount);

        amount = (aumInUsdg == 0 ? usdgAmount : ((usdgAmount * PRICE_PRECISION) / getGlpPrice()));
        return (amount, feeBasisPoints);
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
