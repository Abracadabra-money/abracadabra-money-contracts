// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "libraries/SolidlyOneSidedVolatile.sol";
import "interfaces/ISolidlyPair.sol";
import "interfaces/ISolidlyLpWrapper.sol";
import "interfaces/IVelodromePairFactory.sol";
import "interfaces/ISolidlyGauge.sol";

interface ISolidlyGaugeVolatileLPStrategy {
    function rewardToken() external view returns (address);

    function pairInputToken() external view returns (address);

    function gauge() external view returns (ISolidlyGauge);
}

contract SolidlyStrategyLens {
    function pendingPairClaimable(ISolidlyPair pair, address account) public view returns (uint256 claimable0, uint256 claimable1) {
        claimable0 = pair.claimable0(account);
        claimable1 = pair.claimable1(account);

        uint256 _supplied = pair.balanceOf(account); // get LP balance of `account`
        if (_supplied > 0) {
            uint256 _supplyIndex0 = pair.supplyIndex0(account); // get last adjusted index0 for account
            uint256 _supplyIndex1 = pair.supplyIndex1(account);
            uint256 _index0 = pair.index0(); // get global index0 for accumulated fees
            uint256 _index1 = pair.index1();
            uint256 _delta0 = _index0 - _supplyIndex0; // see if there is any difference that need to be accrued
            uint256 _delta1 = _index1 - _supplyIndex1;
            if (_delta0 > 0) {
                claimable0 += (_supplied * _delta0) / 1e18; // add accrued difference for each supplied token
            }
            if (_delta1 > 0) {
                claimable1 += (_supplied * _delta1) / 1e18;
            }
        }
    }

    function quoteSolidlyWrapperHarvestAmountOut(
        ISolidlyLpWrapper wrapper,
        ISolidlyRouter router,
        uint256 fee
    ) external view returns (uint256 liquidity) {
        ISolidlyPair pair = ISolidlyPair(address(wrapper.underlying()));
        (uint256 claimable0, uint256 claimable1) = pendingPairClaimable(pair, address(wrapper));
        (address token0, address token1) = pair.tokens();

        SolidlyOneSidedVolatile.AddLiquidityAndOneSideRemainingParams memory params = SolidlyOneSidedVolatile
            .AddLiquidityAndOneSideRemainingParams(
                router,
                pair,
                address(token0),
                address(token1),
                pair.reserve0(),
                pair.reserve1(),
                claimable0,
                claimable1,
                0,
                0,
                address(wrapper),
                fee
            );

        (, , liquidity) = SolidlyOneSidedVolatile.quoteAddLiquidityAndOneSideRemaining(params);
    }

    function quoteSolidlyGaugeVolatileStrategySwapToLPAmount(
        ISolidlyGaugeVolatileLPStrategy strategy,
        ISolidlyPair pair,
        ISolidlyRouter router,
        uint256 fee
    ) external view returns (uint256 liquidity) {
        (address token0, address token1) = pair.tokens();

        address rewardToken = strategy.rewardToken();
        address pairInputToken = strategy.pairInputToken();

        ISolidlyPair rewardSwappingPair = ISolidlyPair(router.pairFor(rewardToken, pairInputToken, false));
        uint256 pendingEstimatedRewardAmount = strategy.gauge().earned(rewardToken, address(strategy));
        uint256 amountIn = IERC20(rewardToken).balanceOf(address(strategy)) + pendingEstimatedRewardAmount;
        uint256 amountOut = rewardSwappingPair.getAmountOut(amountIn, rewardToken);

        SolidlyOneSidedVolatile.AddLiquidityFromSingleTokenParams memory _addLiquidityFromSingleTokenParams = SolidlyOneSidedVolatile
            .AddLiquidityFromSingleTokenParams(
                router,
                pair,
                token0,
                token1,
                pair.reserve0(),
                pair.reserve1(),
                pairInputToken,
                amountOut,
                address(this),
                fee
            );

        (, , liquidity) = SolidlyOneSidedVolatile.quoteAddLiquidityFromSingleToken(_addLiquidityFromSingleTokenParams);
    }
}
