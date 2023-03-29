// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/BoringOwnable.sol";
import "BoringSolidity/libraries/BoringERC20.sol";
import "./ERC4626.sol";
import "interfaces/ILPStaking.sol";

/// @dev adapted from https://ape.tessera.co/
/// https://etherscan.io/address/0x7966c5bae631294d7cffcea5430b78c2f76db6fa
contract StargateWrapper is ERC4626, BoringOwnable {
    using BoringERC20 for ERC20;

    error ErrInvalidFeePercent();

    event LogHarvest(uint256 totalRewards, uint256 userRewards, uint256 fees);
    event LogFeeParametersChanged(address indexed feeCollector, uint16 feeAmount);
    event LogStrategyExecutorChanged(address indexed executor, bool allowed);

    // ApeCoinStaking requires at least 1 APE per deposit.
    uint256 public constant BIPS = 10_000;
    uint256 public immutable pid;
    ERC20 public immutable reward;

    ILPStaking public immutable staking;
    uint16 public feePercentBips;
    address public feeCollector;

    constructor(
        ERC20 __asset,
        ERC20 _reward,
        string memory _name,
        string memory _symbol,
        ILPStaking _staking,
        uint256 _pid
    ) {
        _asset = __asset;
        reward = _reward;
        name = _name;
        symbol = _symbol;
        staking = _staking;
        pid = _pid;

        __asset.approve(address(_staking), type(uint256).max);
    }

    function setFeeParameters(address _feeCollector, uint16 _feePercentBips) external onlyOwner {
        if (feePercentBips > BIPS) {
            revert ErrInvalidFeePercent();
        }

        feeCollector = _feeCollector;
        feePercentBips = _feePercentBips;

        emit LogFeeParametersChanged(_feeCollector, _feePercentBips);
    }

    function totalAssets() public view override returns (uint256) {
        uint256 balance = _asset.balanceOf(address(this));
        return balance;
    }

    function _afterDeposit(uint256 assets, uint256) internal override {
        harvest();
        staking.deposit(pid, assets);
    }

    function _beforeWithdraw(uint256 assets, uint256) internal override {
        harvest();
        staking.withdraw(pid, assets);
    }

    function harvest() public {
        staking.withdraw(pid, 0);
        reward.safeTransfer(feeCollector, reward.balanceOf(address(this)));
    }
}
