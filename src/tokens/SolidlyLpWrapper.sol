// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "tokens/ERC20Vault.sol";
import "interfaces/ISolidlyPair.sol";
import "interfaces/ISolidlyRouter.sol";
import "interfaces/ISolidlyLpWrapper.sol";
import "interfaces/IVelodromePairFactory.sol";
import "libraries/SolidlyOneSidedVolatile.sol";
import "interfaces/IVaultHarvester.sol";
import "libraries/SafeTransferLib.sol";

contract SolidlyLpWrapper is ISolidlyLpWrapper, ERC20Vault {
    using SafeTransferLib for IERC20;

    error NotHarvester();
    error NotStrategyExecutor();
    error InsufficientAmountOut();
    error InvalidFeePercent();

    event RewardHarvested(uint256 total, uint256 vaultAmount, uint256 feeAmount);
    event HarvesterChanged(IVaultHarvester indexed oldHarvester, IVaultHarvester indexed newHarvester);
    event FeeParametersChanged(address indexed feeCollector, uint256 feeAmount);
    event StrategyExecutorChanged(address indexed executor, bool allowed);

    ISolidlyPair public immutable pair;
    address public immutable token0;
    address public immutable token1;

    address public feeCollector;
    uint8 public feePercent;
    IVaultHarvester public harvester;

    mapping(address => bool) public strategyExecutors;

    modifier onlyExecutor() {
        if (!strategyExecutors[msg.sender]) {
            revert NotStrategyExecutor();
        }
        _;
    }

    constructor(
        ISolidlyPair _pair,
        string memory _name,
        string memory _symbol,
        uint8 decimals
    ) ERC20Vault(IERC20(address(_pair)), _name, _symbol, decimals) {
        pair = _pair;
        (token0, token1) = _pair.tokens();
    }

    function harvest(uint256 minAmountOut) external onlyExecutor returns (uint256 amountOut) {
        ISolidlyPair(address(underlying)).claimFees();
        IERC20(token0).safeTransfer(address(harvester), IERC20(token0).balanceOf(address(this)));
        IERC20(token1).safeTransfer(address(harvester), IERC20(token1).balanceOf(address(this)));

        uint256 amountBefore = underlying.balanceOf(address(this));

        IVaultHarvester(harvester).harvest(address(this));

        uint256 total = underlying.balanceOf(address(this)) - amountBefore;
        if (total < minAmountOut) {
            revert InsufficientAmountOut();
        }

        uint256 feeAmount = (total * feePercent) / 100;

        if (feeAmount > 0) {
            amountOut = total - feeAmount;
            underlying.safeTransfer(feeCollector, feeAmount);
        }

        emit RewardHarvested(total, amountOut, feeAmount);
    }

    function setStrategyExecutor(address executor, bool value) external onlyOwner {
        strategyExecutors[executor] = value;
        emit StrategyExecutorChanged(executor, value);
    }

    function setHarvester(IVaultHarvester _harvester) external onlyOwner {
        IVaultHarvester previousHarvester = harvester;
        harvester = _harvester;
        emit HarvesterChanged(previousHarvester, _harvester);
    }

    function setFeeParameters(address _feeCollector, uint8 _feePercent) external onlyOwner {
        if (feePercent > 100) {
            revert InvalidFeePercent();
        }

        feeCollector = _feeCollector;
        feePercent = _feePercent;

        emit FeeParametersChanged(_feeCollector, _feePercent);
    }
}
