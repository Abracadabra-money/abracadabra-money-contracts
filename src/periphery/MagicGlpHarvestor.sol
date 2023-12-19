// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {BoringOwnable} from "BoringSolidity/BoringOwnable.sol";
import {BoringERC20} from "BoringSolidity/libraries/BoringERC20.sol";
import {Operatable} from "mixins/Operatable.sol";
import {IMagicGlpRewardHandler} from "interfaces/IMagicGlpRewardHandler.sol";
import {IGmxGlpRewardRouter, IGmxRewardRouterV2, IGmxRewardTracker} from "interfaces/IGmxV1.sol";
import {IWETHAlike} from "interfaces/IWETH.sol";
import {IERC4626} from "interfaces/IERC4626.sol";

/// @dev Glp harvester version that swap the reward to USDC to mint glp
/// and transfer them back in GmxGlpVault token for auto compounding
contract MagicGlpHarvestor is Operatable {
    using BoringERC20 for IERC20;
    using BoringERC20 for IWETHAlike;

    error ErrInvalidFeePercent();
    error ErrNotRewardToken();

    event LogFeeParametersChanged(address indexed feeCollector, uint16 feeAmount);
    event LogRewardRouterV2Changed(IGmxRewardRouterV2 indexed, IGmxRewardRouterV2 indexed);
    event LogHarvest(uint256 total, uint256 amount, uint256 fee);

    uint256 public constant BIPS = 10_000;

    IMagicGlpRewardHandler public immutable vault;
    IERC20 public immutable asset;
    IWETHAlike public immutable rewardToken;

    IGmxRewardRouterV2 public rewardRouterV2;
    IGmxGlpRewardRouter public glpRewardRouter;
    uint64 public lastExecution;

    address public feeCollector;
    uint16 public feePercentBips;

    bool public useDistributeRewardsFeature;

    constructor(
        IWETHAlike _rewardToken,
        IGmxRewardRouterV2 _rewardRouterV2,
        IGmxGlpRewardRouter _glpRewardRouter,
        IMagicGlpRewardHandler _vault,
        bool _useDistributeRewardsFeature
    ) {
        rewardToken = _rewardToken;
        rewardRouterV2 = _rewardRouterV2;
        glpRewardRouter = _glpRewardRouter;
        vault = _vault;
        useDistributeRewardsFeature = _useDistributeRewardsFeature;

        asset = IERC4626(address(vault)).asset();
        asset.approve(address(_vault), type(uint256).max);
    }

    // Only accept native reward token from rewardToken.withdraw calls
    receive() external payable virtual {
        if (msg.sender != address(rewardToken)) {
            revert ErrNotRewardToken();
        }
    }

    function claimable() external view returns (uint256) {
        return
            IGmxRewardTracker(rewardRouterV2.feeGmxTracker()).claimable(address(vault)) +
            IGmxRewardTracker(rewardRouterV2.feeGlpTracker()).claimable(address(vault));
    }

    /// @dev if deploying a new version of this contract, add `+ address(this).balance` as well.
    /// keeping it as is to match what is currently onchain.
    function totalRewardsBalanceAfterClaiming() external view returns (uint256) {
        return
            rewardToken.balanceOf(address(vault)) +
            rewardToken.balanceOf(address(this)) +
            IGmxRewardTracker(rewardRouterV2.feeGmxTracker()).claimable(address(vault)) +
            IGmxRewardTracker(rewardRouterV2.feeGlpTracker()).claimable(address(vault));
    }

    function run(uint256 minGlp, uint256 rewardAmount) external onlyOperators {
        vault.harvest();

        rewardToken.safeTransferFrom(address(vault), address(this), rewardToken.balanceOf(address(vault)));
        rewardToken.withdraw(rewardToken.balanceOf(address(this)));

        if (rewardAmount > address(this).balance) {
            rewardAmount = address(this).balance;
        }

        uint256 total = glpRewardRouter.mintAndStakeGlpETH{value: rewardAmount}(0, minGlp);
        uint256 assetAmount = total;
        uint256 feeAmount = (total * feePercentBips) / BIPS;

        if (feeAmount > 0) {
            assetAmount -= feeAmount;
            asset.safeTransfer(feeCollector, feeAmount);
        }

        if (useDistributeRewardsFeature) {
            vault.distributeRewards(assetAmount);
        } else {
            asset.safeTransfer(address(vault), assetAmount);
        }

        lastExecution = uint64(block.timestamp);

        emit LogHarvest(total, assetAmount, feeAmount);
    }

    function setRewardRouterV2(IGmxRewardRouterV2 _rewardRouterV2) external onlyOwner {
        emit LogRewardRouterV2Changed(rewardRouterV2, _rewardRouterV2);
        rewardRouterV2 = _rewardRouterV2;
    }

    function setFeeParameters(address _feeCollector, uint16 _feePercentBips) external onlyOwner {
        if (feePercentBips > BIPS) {
            revert ErrInvalidFeePercent();
        }

        feeCollector = _feeCollector;
        feePercentBips = _feePercentBips;

        emit LogFeeParametersChanged(_feeCollector, _feePercentBips);
    }
}
