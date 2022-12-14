// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/interfaces/IERC20.sol";
import "BoringSolidity/BoringOwnable.sol";
import "BoringSolidity/libraries/BoringERC20.sol";
import "BoringSolidity/libraries/BoringRebase.sol";
import "interfaces/IGmxGlpVaultRewardHandler.sol";
import "libraries/CauldronTargetApyDistribution.sol";
import "interfaces/IGmxRewardRouterV2.sol";
import "interfaces/IGmxRewardTracker.sol";
import "interfaces/IWETH.sol";
import "interfaces/IERC4626.sol";

/// @dev used to receive distribution allocations from CauldronTargetApyDistribution
interface IGlpVaultHarvestorDistributionRecipient {
    function previewDistributeToRecipient(CauldronTargetApyDistributionItem memory info, uint256 amount) external view returns (uint256);

    function distributeToRecipient(
        CauldronTargetApyDistributionItem memory info,
        uint256 amount,
        bytes memory recipientSpecificData
    ) external;
}

/// @dev Glp harvester version that swap the reward to USDC to mint glp
/// and transfer them back in GmxGlpVault token for auto compounding
contract GlpVaultHarvestor is BoringOwnable {
    using CauldronTargetApyDistribution for CauldronTargetApyDistributionItem[];
    using BoringERC20 for IERC20;
    using BoringERC20 for IWETH;

    event LogPaused(bool previous, bool current);
    event LogOperatorChanged(address indexed, bool);
    event LogRewardRouterV2Changed(IGmxRewardRouterV2 indexed, IGmxRewardRouterV2 indexed);
    event LogFeeParametersChanged(address indexed feeCollector, uint256 feeAmount);
    event LogDistributionParameterChanged(ICauldronV2 indexed cauldron, address indexed recipient, uint256 targetApy);
    event LogSwappingTokenOutUpdated(IERC20 indexed token, bool enabled);
    event LogSwapperChanged(address indexed oldSwapper, address indexed newSwapper);
    event LogRewardSwapped(IERC20 indexed tokenIn, IERC20 indexed tokenOut, uint256 amountOut);

    error ErrInsufficientAmountOut();
    error ErrSwapFailed();
    error ErrUnsupportedOutputToken(IERC20 token);
    error ErrPaused(bool);
    error ErrInvalidFeePercent();
    error ErrNotAllowedOperator();

    struct FeeSwapInfo {
        uint256 amountOutMin;
        IERC20 outputToken;
        bytes swapData;
    }

    IGmxGlpVaultRewardHandler public immutable vault;
    IWETH public immutable weth;

    CauldronTargetApyDistributionItem[] public distributions;
    address public feeCollector;
    uint8 public feePercent;

    address public swapper;
    IGmxRewardRouterV2 public rewardRouterV2;

    mapping(address => bool) public operators;
    mapping(IERC20 => bool) public swappingTokenOutEnabled;

    uint64 public lastExecution;
    bool public paused;

    modifier onlyOperators() {
        if (msg.sender != owner && !operators[msg.sender]) {
            revert ErrNotAllowedOperator();
        }
        _;
    }

    modifier notPaused() {
        if (paused) {
            revert ErrPaused(true);
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

    function getDistributionInfoCount() external view returns (uint256) {
        return distributions.length;
    }

    function getDistributionInfo(uint256 index) external view returns (CauldronTargetApyDistributionItem memory) {
        return distributions[index];
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

    function previewDistribution() external view returns (uint256[] memory distributionAllocations, uint256 feeAmount) {
        (distributionAllocations, feeAmount) = distributions.previewDistribution(
            weth.balanceOf(address(this)),
            _previewDistributeToRecipient
        );
    }

    function run(bytes[] memory recipientSpecificData, FeeSwapInfo memory feeSwapInfo) external onlyOperators notPaused {
        vault.harvest();
        weth.safeTransferFrom(address(vault), address(this), weth.balanceOf(address(vault)));

        (uint256[] memory distributionAllocations, uint256 feeAmount) = distributions.previewDistribution(
            weth.balanceOf(address(this)),
            _previewDistributeToRecipient
        );

        distributions.distribute(distributionAllocations, recipientSpecificData, _distributeToRecipient);

        feeAmount = (feeAmount * feePercent) / 100;
        if (feeAmount > 0) {
            if (feeSwapInfo.swapData.length == 0) {
                weth.safeTransfer(feeCollector, feeAmount);
            } else {
                _swapFeesAndTransfer(feeSwapInfo.amountOutMin, feeSwapInfo.outputToken, feeSwapInfo.swapData);
            }
        }

        lastExecution = uint64(block.timestamp);
    }

    function _swapFeesAndTransfer(
        uint256 amountOutMin,
        IERC20 outputToken,
        bytes memory data
    ) private {
        if (!swappingTokenOutEnabled[outputToken]) {
            revert ErrUnsupportedOutputToken(outputToken);
        }

        uint256 amountBefore = IERC20(outputToken).balanceOf(address(this));
        weth.approve(swapper, weth.balanceOf(address(this)));

        (bool success, ) = swapper.call(data);
        if (!success) {
            revert ErrSwapFailed();
        }

        uint256 amountOut = IERC20(outputToken).balanceOf(address(this)) - amountBefore;

        if (amountOut < amountOutMin) {
            revert ErrInsufficientAmountOut();
        }

        IERC20(outputToken).safeTransfer(address(vault), amountOut);
        weth.approve(swapper, 0);

        emit LogRewardSwapped(weth, outputToken, amountOut);
    }

    function _distributeToRecipient(
        CauldronTargetApyDistributionItem memory info,
        uint256 amount,
        bytes memory recipientSpecificData
    ) private {
        weth.safeTransferFrom(address(vault), info.recipient, amount);
        IGlpVaultHarvestorDistributionRecipient(info.recipient).distributeToRecipient(info, amount, recipientSpecificData);
    }

    function _previewDistributeToRecipient(CauldronTargetApyDistributionItem memory info, uint256 amount) private view returns (uint256) {
        return IGlpVaultHarvestorDistributionRecipient(info.recipient).previewDistributeToRecipient(info, amount);
    }

    /// @param token The allowed token out support when swapping rewards
    function setSwappingTokenOutEnabled(IERC20 token, bool enabled) external onlyOwner {
        swappingTokenOutEnabled[token] = enabled;
        emit LogSwappingTokenOutUpdated(token, enabled);
    }

    function setPaused(bool _paused) external onlyOwner {
        emit LogPaused(paused, _paused);
        paused = _paused;
    }

    function setDistributionInfo(
        ICauldronV2 cauldron,
        IGlpVaultHarvestorDistributionRecipient _recipient,
        uint256 _targetApyBips
    ) external onlyOwner {
        distributions.setDistributionInfo(cauldron, address(_recipient), _targetApyBips);
        emit LogDistributionParameterChanged(cauldron, address(_recipient), _targetApyBips);
    }

    function setOperator(address operator, bool status) external onlyOwner {
        operators[operator] = status;
        emit LogOperatorChanged(operator, status);
    }

    function setRewardRouterV2(IGmxRewardRouterV2 _rewardRouterV2) external onlyOwner {
        emit LogRewardRouterV2Changed(rewardRouterV2, _rewardRouterV2);
        rewardRouterV2 = _rewardRouterV2;
    }

    function setSwapper(address _swapper) external onlyOwner {
        emit LogSwapperChanged(swapper, _swapper);
        swapper = _swapper;
    }

    function setFeeParameters(address _feeCollector, uint8 _feePercent) external onlyOwner {
        if (_feePercent > 100) {
            revert ErrInvalidFeePercent();
        }

        feeCollector = _feeCollector;
        feePercent = _feePercent;

        emit LogFeeParametersChanged(_feeCollector, _feePercent);
    }

    /**
     * Emergency / Migration
     */
    function withdraw(
        IERC20 token,
        uint256 amount,
        uint256 value
    ) external onlyOwner {
        if (!paused) {
            revert ErrPaused(false);
        }

        token.safeTransfer(owner, amount);

        // solhint-disable-next-line avoid-low-level-calls
        if (value > 0) {
            (bool success, ) = owner.call{value: value}("");
            require(success);
        }
    }
}

/// @notice receive wETH rewards from the harvestor, mint glp and transfer to the vault
/// This way every distributor recipient is of type `IGlpVaultHarvestorDistributionRecipient`
contract GlpVaultDistributionDispatcher is IGlpVaultHarvestorDistributionRecipient {
    using BoringERC20 for IERC20;

    IWETH public immutable weth;
    IGmxRewardRouterV2 public immutable rewardRouterV2;

    constructor(IWETH _weth, IGmxRewardRouterV2 _rewardRouterV2) {
        weth = _weth;
        rewardRouterV2 = _rewardRouterV2;
    }

    function previewDistributeToRecipient(CauldronTargetApyDistributionItem memory, uint256 amount) external pure returns (uint256) {
        return amount;
    }

    function distributeToRecipient(
        CauldronTargetApyDistributionItem memory info,
        uint256 amount,
        bytes memory recipientSpecificData
    ) external {
        uint256 minGlp = abi.decode(recipientSpecificData, (uint256));
        weth.withdraw(amount);
        uint256 glpAmount = rewardRouterV2.mintAndStakeGlpETH{value: address(this).balance}(0, minGlp);

        IERC20 asset = IERC4626(info.recipient).asset();
        asset.safeTransfer(info.recipient, glpAmount);
    }
}
