// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/interfaces/IERC20.sol";
import "libraries/MathLib.sol";
import "interfaces/IGmxVault.sol";
import "interfaces/IGmxGlpManager.sol";
import "interfaces/IGmxVaultPriceFeed.sol";
import "forge-std/console2.sol";

struct GmxLensManagerInMemoryState {
    IGmxGlpManager manager;
    uint256 aumAddition;
    uint256 aumDeduction;
}
struct GmxLensGlpInMemoryState {
    IERC20 glp;
    uint256 totalSupply;
}

struct GmxLensVaultInMemoryState {
    IGmxVault vault;
    address[] tokens;
    uint256[] usdgAmounts;
    uint256[] maxUsdgAmounts;
    uint256[] poolAmounts;
    uint256[] reservedAmounts;
    GmxLensGlpInMemoryState glpState;
    GmxLensManagerInMemoryState managerState;
}

library GmxLensVaultInMemoryLib {
    uint256 internal constant USDG_DECIMALS = 18;
    uint256 internal constant PRECISION = 10**18;
    uint256 internal constant PRICE_PRECISION = 10**30;

    function initialize(
        address[] memory tokens,
        IGmxGlpManager manager,
        IGmxVault vault,
        IERC20 glp
    ) internal view returns (GmxLensVaultInMemoryState memory inMemoryVault) {
        inMemoryVault.vault = vault;
        inMemoryVault.tokens = new address[](tokens.length);
        inMemoryVault.usdgAmounts = new uint256[](tokens.length);
        inMemoryVault.maxUsdgAmounts = new uint256[](tokens.length);
        inMemoryVault.poolAmounts = new uint256[](tokens.length);
        inMemoryVault.reservedAmounts = new uint256[](tokens.length);

        inMemoryVault.managerState = GmxLensManagerInMemoryState({
            aumAddition: manager.aumAddition(),
            aumDeduction: manager.aumDeduction(),
            manager: manager
        });
        inMemoryVault.glpState = GmxLensGlpInMemoryState({totalSupply: glp.totalSupply(), glp: glp});

        for (uint256 i = 0; i < tokens.length; ) {
            address token = tokens[i];
            inMemoryVault.tokens[i] = token;
            inMemoryVault.usdgAmounts[i] = vault.usdgAmounts(token);
            inMemoryVault.maxUsdgAmounts[i] = vault.maxUsdgAmounts(token);
            inMemoryVault.poolAmounts[i] = vault.poolAmounts(token);
            inMemoryVault.reservedAmounts[i] = vault.reservedAmounts(token);
            unchecked {
                ++i;
            }
        }
    }

    function getUsdgLeftToDeposit(GmxLensVaultInMemoryState memory state, uint256 i) internal pure returns (uint256) {
        return state.maxUsdgAmounts[i] - state.usdgAmounts[i];
    }

    function getUsdgLeftToWithdraw(GmxLensVaultInMemoryState memory state, uint256 i) internal view returns (uint256) {
        return state.vault.tokenToUsdMin(state.tokens[i], state.poolAmounts[i] - state.reservedAmounts[i]) / 1e12;
    }

    function getGlpPrice(GmxLensVaultInMemoryState memory state) internal view returns (uint256) {
        return (getAumInUsdg(state) * PRICE_PRECISION) / state.glpState.glp.totalSupply();
    }

    function getAumInUsdg(GmxLensVaultInMemoryState memory state) internal view returns (uint256) {
        uint256 aum = getAum(state);
        return (aum * (10**USDG_DECIMALS)) / PRICE_PRECISION;
    }

    function getAum(GmxLensVaultInMemoryState memory state) internal view returns (uint256) {
        uint256 length = state.vault.allWhitelistedTokensLength();
        uint256 aumDeduction = state.managerState.aumDeduction;
        uint256 aum = state.managerState.aumAddition;
        uint256 shortProfits = 0;

        for (uint256 i = 0; i < length; i++) {
            address token = state.vault.allWhitelistedTokens(i);
            bool isWhitelisted = state.vault.whitelistedTokens(token);

            if (!isWhitelisted) {
                continue;
            }

            uint256 price = state.vault.getMinPrice(token);
            uint256 poolAmount = state.vault.poolAmounts(token);
            uint256 decimals = state.vault.tokenDecimals(token);

            if (state.vault.stableTokens(token)) {
                aum += ((poolAmount * price) / 10**decimals);
            } else {
                uint256 size = state.vault.globalShortSizes(token);

                if (size > 0) {
                    (uint256 delta, bool hasProfit) = state.managerState.manager.getGlobalShortDelta(token, price, size);
                    if (!hasProfit) {
                        aum += delta;
                    } else {
                        shortProfits += delta;
                    }
                }

                aum += state.vault.guaranteedUsd(token);

                uint256 reservedAmount = state.vault.reservedAmounts(token);
                aum += ((poolAmount - reservedAmount) * price) / 10**decimals;
            }
        }

        aum = shortProfits > aum ? 0 : aum - shortProfits;
        return aumDeduction > aum ? 0 : aum - aumDeduction;
    }
}

contract GmxLens {
    using GmxLensVaultInMemoryLib for GmxLensVaultInMemoryState;

    uint256 private constant BASIS_POINTS_DIVISOR = 10000;
    uint256 private constant PRICE_PRECISION = 10**30;
    uint256 private constant USDG_DECIMALS = 18;
    uint256 private constant PRECISION = 10**18;

    IGmxGlpManager public immutable manager;
    IGmxVault public immutable vault;

    IERC20 private immutable glp;
    IERC20 private immutable usdg;

    struct GlpBurningPart {
        // slot 1
        uint128 glpAmount;
        uint128 tokenAmount;
        // slot1
        address token;
        uint8 feeBasisPoints;
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

    function getUsdgLeftToWithdraw(address token) public view returns (uint256) {
        return vault.tokenToUsdMin(token, vault.poolAmounts(token) - vault.reservedAmounts(token)) / 1e12;
    }

    function getTokenOutPartsFromBurningGlp(uint256 glpAmount, address[] memory tokens)
        public
        view
        returns (GlpBurningPart[] memory burningParts, uint16 burningPartsLength)
    {
        GmxLensVaultInMemoryState memory inMemoryVault = GmxLensVaultInMemoryLib.initialize(tokens, manager, vault, glp);
        uint256 glpPrice = inMemoryVault.getGlpPrice();
        uint256 usdgLeftToSell = (glpAmount * glpPrice) / PRICE_PRECISION;
        uint16 poolsAvailable = uint16((1 << tokens.length)) - 1;
        uint8 burningPartIndex = 0;
        burningParts = new GlpBurningPart[](tokens.length);

        for (;;) {
            GlpBurningPart memory burningPart = GlpBurningPart({
                token: address(0),
                glpAmount: 0,
                tokenAmount: 0,
                feeBasisPoints: type(uint8).max
            });

            uint128 usdgAmountSold;

            // for the amount of glp we need to burn, search for the pool
            // giving out the best rate
            for (uint256 i = 0; i < tokens.length; ) {
                if ((poolsAvailable & (1 << i)) == 0) {
                    continue;
                }

                address token = tokens[i];
                uint256 leftToWithdraw = inMemoryVault.getUsdgLeftToWithdraw(i);

                console2.log(token, "leftToWithdraw", leftToWithdraw);

                // ignore empty pools
                if (leftToWithdraw <= 1e18) {
                    continue;
                }

                (uint256 potentialAmountOut, uint256 potentialFeeBasisPoints) = getTokenOutFromSellingUsdg(token, usdgLeftToSell);

                // are the fees better than they previous pool we tried?
                if (potentialFeeBasisPoints < burningPart.feeBasisPoints) {
                    usdgAmountSold = uint128(MathLib.min(usdgLeftToSell, leftToWithdraw));
                    burningPart.token = token;
                    burningPart.glpAmount = uint128((usdgAmountSold * PRICE_PRECISION) / glpPrice);
                    burningPart.tokenAmount = uint128(potentialAmountOut);
                    burningPart.feeBasisPoints = uint8(potentialFeeBasisPoints);

                    // do not consume from this pool again
                    poolsAvailable &= ~uint16(1 << i);
                }

                unchecked {
                    ++i;
                }
            }

            // substract the approximated glpAmount calculated from the usdgAmount from
            // the total glp amount to burn.
            glpAmount = MathLib.subWithZeroFloor(glpAmount, burningPart.glpAmount);

            burningParts[burningPartIndex] = burningPart;
            usdgLeftToSell -= usdgAmountSold;

            // no more usdg to sell nor pool to consume.
            if (usdgLeftToSell == 0 || poolsAvailable == 0) {
                // add rounding glp amount leftover to the last part
                if (glpAmount > 0) {
                    burningParts[burningPartIndex].glpAmount += uint128(glpAmount);
                }

                burningPartsLength = uint16(burningPartIndex + 1);
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
