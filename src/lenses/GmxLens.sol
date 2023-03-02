// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/interfaces/IERC20.sol";
import "libraries/MathLib.sol";
import "interfaces/IGmxVault.sol";
import "interfaces/IGmxGlpManager.sol";
import "interfaces/IGmxVaultPriceFeed.sol";
import "forge-std/console2.sol";

contract GmxLens {
    uint256 private constant BASIS_POINTS_DIVISOR = 10000;
    uint256 private constant PRICE_PRECISION = 10**30;
    uint256 private constant USDG_DECIMALS = 18;
    uint256 private constant PRECISION = 10**18;

    IGmxGlpManager public immutable manager;
    IGmxVault public immutable vault;

    IERC20 private immutable glp;
    IERC20 private immutable usdg;

    struct GlpBurningPart {
        uint128 usdgAmount;
        uint128 glpAmount;
        uint128 tokenAmount;
        uint8 feeBasisPoints;
        bool valid;
    }

    constructor(IGmxGlpManager _manager, IGmxVault _vault) {
        manager = _manager;
        vault = _vault;
        glp = IERC20(manager.glp());
        usdg = IERC20(manager.usdg());
    }

    function getGlpPrice() public view returns (uint256) {
        return (manager.getAumInUsdg(false) * PRICE_PRECISION) / glp.totalSupply();
    }

    function getUsdgLeftToDeposit(address token) public view returns (uint256) {
        return vault.maxUsdgAmounts(token) - vault.usdgAmounts(token);
    }

    function getUsdgLeftToWithdraw(address token) public view returns (uint256) {
        return vault.tokenToUsdMin(token, vault.poolAmounts(token) - vault.reservedAmounts(token)) / 1e12;
    }

    function getTokenOutPartsFromBurningGlp(uint256 glpAmount, address[] memory tokens)
        public
        view
        returns (GlpBurningPart[] memory burningParts, uint16 burningPartsLength)
    {
        uint256 usdgLeftToSell = (glpAmount * getGlpPrice()) / PRICE_PRECISION;
        uint256 glpPrice = getGlpPrice();
        uint16 poolsAvailable = uint16((1 << tokens.length)) - 1;
        uint8 burningPartIndex = 0;
        burningParts = new GlpBurningPart[](tokens.length);

        for (;;) {
            GlpBurningPart memory burningPart = GlpBurningPart({
                usdgAmount: 0,
                glpAmount: 0,
                tokenAmount: 0,
                feeBasisPoints: type(uint8).max,
                valid: true
            });

            // for the amount of glp we need to burn, search for the pool
            // giving out the best rate
            for (uint256 i = 0; i < tokens.length; ) {
                if ((poolsAvailable & (1 << i)) == 0) {
                    continue;
                }

                address token = tokens[i];
                uint256 leftToWithdraw = getUsdgLeftToWithdraw(token);

                //console2.log(token, "leftToWithdraw", leftToWithdraw);

                // ignore empty pools
                if (leftToWithdraw <= 1e18) {
                    continue;
                }

                (uint256 potentialAmountOut, uint256 potentialFeeBasisPoints) = getTokenOutFromSellingUsdg(token, usdgLeftToSell);

                // are the fees better than they previous pool we tried?
                if (potentialFeeBasisPoints < burningPart.feeBasisPoints) {
                    burningPart.usdgAmount = uint128(MathLib.min(usdgLeftToSell, leftToWithdraw));
                    burningPart.glpAmount = uint128((burningPart.usdgAmount * PRICE_PRECISION) / glpPrice);
                    burningPart.tokenAmount = uint128(potentialAmountOut);
                    burningPart.feeBasisPoints = uint8(potentialFeeBasisPoints);

                    // substract the approximated glpAmount calculated from the usdgAmount from
                    // the total glp amount to burn.
                    glpAmount = MathLib.subWithZeroFloor(glpAmount, burningPart.glpAmount);

                    // do not consume from this pool again
                    poolsAvailable &= ~uint16(1 << i);
                }

                unchecked {
                    ++i;
                }
            }

            burningParts[burningPartIndex] = burningPart;
            usdgLeftToSell -= burningPart.usdgAmount;

            // no more usdg to sell nor pool to consume.
            if (usdgLeftToSell == 0 || poolsAvailable == 0) {
                // add rounding glp amount leftover to the last part
                if (glpAmount > 0) {
                    burningParts[burningPartIndex++].glpAmount += uint128(glpAmount);
                }

                burningPartsLength = uint16(burningPartIndex);
                break;
            }

            ++burningPartIndex;
        }
    }

    function getTokenOutFromBurningGlp(address tokenOut, uint256 glpAmount) public view returns (uint256 amount, uint256 feeBasisPoints) {
        uint256 usdgAmount = (glpAmount * getGlpPrice()) / PRICE_PRECISION;
        return getTokenOutFromSellingUsdg(tokenOut, usdgAmount);
    }

    function getTokenOutFromSellingUsdg(address tokenOut, uint256 usdgAmount) public view returns (uint256 amount, uint256 feeBasisPoints) {
        feeBasisPoints = _getFeeBasisPoints(
            tokenOut,
            vault.usdgAmounts(tokenOut) - usdgAmount,
            usdgAmount,
            vault.mintBurnFeeBasisPoints(),
            vault.taxBasisPoints(),
            false
        );

        uint256 redemptionAmount = vault.getRedemptionAmount(tokenOut, usdgAmount);
        amount = _collectSwapFees(redemptionAmount, feeBasisPoints);
    }

    function getMintedGlpFromTokenIn(address tokenIn, uint256 amount) external view returns (uint256 amountOut, uint256 feeBasisPoints) {
        uint256 aumInUsdg = manager.getAumInUsdg(true);
        uint256 usdgAmount;
        (usdgAmount, feeBasisPoints) = _simulateBuyUSDG(tokenIn, amount, vault.usdgAmounts(tokenIn));

        amountOut = (aumInUsdg == 0 ? usdgAmount : ((usdgAmount * PRICE_PRECISION) / getGlpPrice()));
    }

    function getUsdgAmountFromTokenIn(address tokenIn, uint256 tokenAmount) public view returns (uint256 usdgAmount) {
        uint256 price = vault.getMinPrice(tokenIn);
        uint256 rawUsdgAmount = (tokenAmount * price) / PRICE_PRECISION;
        return vault.adjustForDecimals(rawUsdgAmount, tokenIn, address(usdg));
    }

    function _simulateBuyUSDG(
        address tokenIn,
        uint256 tokenAmount,
        uint256 currentUsdgAmount
    ) private view returns (uint256 mintAmount, uint256 feeBasisPoints) {
        uint256 usdgAmount = getUsdgAmountFromTokenIn(tokenIn, tokenAmount);

        feeBasisPoints = _getFeeBasisPoints(
            tokenIn,
            currentUsdgAmount, /*vault.usdgAmounts(tokenIn)*/
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

        uint256 targetAmount = vault.getTargetUsdgAmount(_token);
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
}
