// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/interfaces/IERC20.sol";
import "BoringSolidity/BoringOwnable.sol";
import "BoringSolidity/libraries/BoringERC20.sol";
import "BoringSolidity/libraries/BoringRebase.sol";
import "periphery/Operatable.sol";
import "interfaces/IMagicGlpRewardHandler.sol";
import "interfaces/IGmxRewardRouterV2.sol";
import "interfaces/IGmxGlpRewardRouter.sol";
import "interfaces/IGmxRewardTracker.sol";
import "interfaces/IWETH.sol";
import "interfaces/IERC4626.sol";

/// @dev Glp harvester version that swap the reward to USDC to mint glp
/// and transfer them back in GmxGlpVault token for auto compounding
contract MagicGlpHarvestor is Operatable {
    using BoringERC20 for IERC20;
    using BoringERC20 for IWETH;

    error ErrInvalidFeePercent();
    error ErrNotWeth();

    event LogFeeParametersChanged(address indexed feeCollector, uint16 feeAmount);
    event LogRewardRouterV2Changed(IGmxRewardRouterV2 indexed, IGmxRewardRouterV2 indexed);
    event LogHarvest(uint256 total, uint256 amount, uint256 fee);

    uint256 public constant BIPS = 10_000;

    IMagicGlpRewardHandler public immutable vault;
    IERC20 public immutable asset;
    IWETH public immutable weth;

    IGmxRewardRouterV2 public rewardRouterV2;
    IGmxGlpRewardRouter public glpRewardRouter;
    uint64 public lastExecution;

    address public feeCollector;
    uint16 public feePercentBips;

    constructor(
        IWETH _weth,
        IGmxRewardRouterV2 _rewardRouterV2,
        IGmxGlpRewardRouter _glpRewardRouter,
        IMagicGlpRewardHandler _vault
    ) {
        weth = _weth;
        rewardRouterV2 = _rewardRouterV2;
        glpRewardRouter = _glpRewardRouter;
        vault = _vault;

        asset = IERC4626(address(vault)).asset();
        asset.approve(address(_vault), type(uint256).max);
    }

    // Only accept ETH from wETH.withdraw calls
    receive() external payable virtual {
        if (msg.sender != address(weth)) {
            revert ErrNotWeth();
        }
    }

    function claimable() external view returns (uint256) {
        return
            IGmxRewardTracker(rewardRouterV2.feeGmxTracker()).claimable(address(vault)) +
            IGmxRewardTracker(rewardRouterV2.feeGlpTracker()).claimable(address(vault));
    }

    function totalRewardsBalanceAfterClaiming() external view returns (uint256) {
        return
            weth.balanceOf(address(vault)) +
            IGmxRewardTracker(rewardRouterV2.feeGmxTracker()).claimable(address(vault)) +
            IGmxRewardTracker(rewardRouterV2.feeGlpTracker()).claimable(address(vault));
    }

    function run(uint256 minGlp) external onlyOperators {
        vault.harvest();
        weth.safeTransferFrom(address(vault), address(this), weth.balanceOf(address(vault)));
        weth.withdraw(weth.balanceOf(address(this)));

        uint256 total = glpRewardRouter.mintAndStakeGlpETH{value: address(this).balance}(0, minGlp);
        uint256 assetAmount = total;
        uint256 feeAmount = (total * feePercentBips) / BIPS;
        
        if (feeAmount > 0) {
            assetAmount -= feeAmount;
            asset.safeTransfer(feeCollector, feeAmount);
        }

        vault.distributeRewards(assetAmount);
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
