// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/libraries/BoringERC20.sol";
import "BoringSolidity/BoringOwnable.sol";
import {MagicGlpData} from "tokens/MagicGlp.sol";

interface IKlpRewardHandler {
    function handleRewards(bool _shouldConvertWethToEth, bool _shouldAddIntoKLP) external;
}

contract MagicKlpRewardHandlerDataV1 is MagicGlpData {
    IKlpRewardHandler public rewardRouter;
    IERC20[] public rewardTokens;
    uint16 public feeBips;
    address public feeCollector;
}

contract MagicKlpRewardHandler is MagicKlpRewardHandlerDataV1 {
    using BoringERC20 for IERC20;

    event LogHarvest();
    event LogDistributeRewards(uint256 amount);
    event LogRewardRouterChanged(IKlpRewardHandler indexed previous, IKlpRewardHandler indexed current);
    event LogRewardTokensChanged(IERC20[] previous, IERC20[] current);
    error ErrInvalidFeeBips();
    error ErrInvalidFeeOperator(address);
    event LogFeeParametersChanged(
        address indexed previousFeeCollector,
        uint16 previousFeeAmount,
        address indexed feeCollector,
        uint16 feeAmount
    );

    function harvest() external onlyStrategyExecutor {
        rewardRouter.handleRewards(false, false);

        uint256 userAmount;
        uint256 feeAmount;
        uint256 balance;
        
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            IERC20 rewardToken = rewardTokens[i];
            balance = rewardToken.balanceOf(address(this));
            if (balance > 0) {
                (userAmount, feeAmount) = _calculateFees(balance);
                rewardToken.safeTransfer(msg.sender, userAmount);
                rewardToken.safeTransfer(feeCollector, feeAmount);
            }
        }

        emit LogHarvest();
    }

    function distributeRewards(uint256 amount) external onlyStrategyExecutor {
        _asset.transferFrom(msg.sender, address(this), amount);
        _totalAssets += amount;

        emit LogDistributeRewards(amount);
    }

    function setRewardTokens(IERC20[] memory _rewardTokens) external onlyOwner {
        emit LogRewardTokensChanged(rewardTokens, _rewardTokens);
        rewardTokens = _rewardTokens;
    }

    function setRewardRouter(IKlpRewardHandler _rewardRouter) external onlyOwner {
        emit LogRewardRouterChanged(rewardRouter, _rewardRouter);
        rewardRouter = _rewardRouter;
    }

    function skimAssets() external onlyOwner returns (uint256 amount) {
        amount = _asset.balanceOf(address(this)) - _totalAssets;

        if (amount > 0) {
            _asset.transfer(msg.sender, amount);
        }
    }

    function setFeeParameters(address _feeCollector, uint16 _feeBips) external onlyOwner {
        if (feeBips > 10_000) {
            revert ErrInvalidFeeBips();
        }

        emit LogFeeParametersChanged(feeCollector, feeBips, _feeCollector, _feeBips);

        feeCollector = _feeCollector;
        feeBips = _feeBips;
    }

    function _calculateFees(uint256 amountIn) private view returns (uint userAmount, uint feeAmount) {
        feeAmount = (amountIn * feeBips) / 10_000;
        userAmount = amountIn - feeAmount;
    }
}
