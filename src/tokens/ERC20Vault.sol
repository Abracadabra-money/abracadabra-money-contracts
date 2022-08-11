// SPDX-License-Identifier: MIT
pragma solidity >=0.8.10;
import {ERC20WithSupply} from "BoringSolidity/ERC20.sol";
import "BoringSolidity/BoringOwnable.sol";
import "libraries/SafeTransferLib.sol";
import "interfaces/IVaultHarvester.sol";

abstract contract ERC20Vault is ERC20WithSupply, BoringOwnable {
    using SafeTransferLib for ERC20;

    error NotHarvester();
    error NotStrategyExecutor();
    error InsufficientAmountOut();
    error InvalidFeePercent();

    event RewardHarvested(uint256 total, uint256 vaultAmount, uint256 feeAmount);
    event HarvesterChanged(IVaultHarvester indexed oldHarvester, IVaultHarvester indexed newHarvester);
    event FeeParametersChanged(address indexed feeCollector, uint256 feeAmount);
    event StrategyExecutorChanged(address indexed executor, bool allowed);

    address public immutable underlying;
    uint8 public immutable decimals;

    string public name;
    string public symbol;
    address public feeCollector;
    uint8 public feePercent;
    IVaultHarvester public harvester;

    mapping(address => bool) public strategyExecutors;

    modifier onlyHarvester() {
        if (msg.sender != address(harvester)) {
            revert NotHarvester();
        }
        _;
    }

    modifier onlyExecutor() {
        if (!strategyExecutors[msg.sender]) {
            revert NotStrategyExecutor();
        }
        _;
    }

    constructor(
        address _underlying,
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        underlying = _underlying;
    }

    function _beforeHarvest(IVaultHarvester harvester) internal virtual;

    function harvest(uint256 minAmountOut) external onlyExecutor returns (uint256 amountOut) {
        _beforeHarvest(harvester);

        uint256 amountBefore = ERC20(underlying).balanceOf(address(this));

        IVaultHarvester(harvester).harvest(address(this));

        uint256 total = ERC20(underlying).balanceOf(address(this)) - amountBefore;
        if (total < minAmountOut) {
            revert InsufficientAmountOut();
        }

        uint256 feeAmount = (total * feePercent) / 100;

        if (feeAmount > 0) {
            amountOut = total - feeAmount;
            ERC20(underlying).safeTransfer(feeCollector, feeAmount);
        }

        emit RewardHarvested(total, amountOut, feeAmount);
    }

    function enter(uint256 amount) external returns (uint256 shares) {
        uint256 totalUnderlying = ERC20(underlying).balanceOf(address(this));

        shares = (totalSupply == 0 || totalUnderlying == 0) ? amount : (amount * totalSupply) / totalUnderlying;
        _mint(msg.sender, shares);
        ERC20(underlying).transferFrom(msg.sender, address(this), amount);
    }

    function leave(uint256 share) external returns (uint256 amount) {
        amount = (share * ERC20(underlying).balanceOf(address(this))) / totalSupply;
        _burn(msg.sender, share);
        ERC20(underlying).transfer(msg.sender, amount);
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
