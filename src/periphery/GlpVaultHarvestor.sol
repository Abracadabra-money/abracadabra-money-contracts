// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/interfaces/IERC20.sol";
import "BoringSolidity/BoringOwnable.sol";
import "BoringSolidity/libraries/BoringERC20.sol";
import "BoringSolidity/libraries/BoringRebase.sol";
import "interfaces/IGmxGlpVaultRewardHandler.sol";
import "interfaces/IGmxRewardRouterV2.sol";
import "interfaces/IGmxRewardTracker.sol";
import "interfaces/IWETH.sol";
import "interfaces/IERC4626.sol";

/// @dev Glp harvester version that swap the reward to USDC to mint glp
/// and transfer them back in GmxGlpVault token for auto compounding
contract GlpVaultHarvestor is BoringOwnable {
    using BoringERC20 for IERC20;
    using BoringERC20 for IWETH;

    event LogOperatorChanged(address indexed, bool);
    event LogRewardRouterV2Changed(IGmxRewardRouterV2 indexed, IGmxRewardRouterV2 indexed);

    error ErrNotAllowedOperator();

    IGmxGlpVaultRewardHandler public immutable vault;
    IWETH public immutable weth;

    IGmxRewardRouterV2 public rewardRouterV2;

    mapping(address => bool) public operators;
    uint64 public lastExecution;

    modifier onlyOperators() {
        if (msg.sender != owner && !operators[msg.sender]) {
            revert ErrNotAllowedOperator();
        }
        _;
    }

    constructor(
        IWETH _weth,
        IGmxRewardRouterV2 _rewardRouterV2,
        IGmxGlpVaultRewardHandler _vault
    ) {
        operators[msg.sender] = true;

        weth = _weth;
        rewardRouterV2 = _rewardRouterV2;
        vault = _vault;
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

        uint256 glpAmount = rewardRouterV2.mintAndStakeGlpETH{value: address(this).balance}(0, minGlp);
        IERC20 asset = IERC4626(address(vault)).asset();
        asset.safeTransfer(address(vault), glpAmount);
        lastExecution = uint64(block.timestamp);
    }

    function setOperator(address operator, bool status) external onlyOwner {
        operators[operator] = status;
        emit LogOperatorChanged(operator, status);
    }

    function setRewardRouterV2(IGmxRewardRouterV2 _rewardRouterV2) external onlyOwner {
        emit LogRewardRouterV2Changed(rewardRouterV2, _rewardRouterV2);
        rewardRouterV2 = _rewardRouterV2;
    }
}
