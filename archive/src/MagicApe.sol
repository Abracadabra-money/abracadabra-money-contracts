// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {BoringOwnable} from "BoringSolidity/BoringOwnable.sol";
import {BoringERC20} from "BoringSolidity/libraries/BoringERC20.sol";
import {ERC4626} from "tokens/ERC4626.sol";
import {IApeCoinStaking} from "interfaces/IApeCoinStaking.sol";

/// @dev adapted from https://ape.tessera.co/
/// https://etherscan.io/address/0x7966c5bae631294d7cffcea5430b78c2f76db6fa
contract MagicApe is ERC4626, BoringOwnable {
    using BoringERC20 for ERC20;

    error ErrInvalidFeePercent();

    event LogHarvest(uint256 totalRewards, uint256 userRewards, uint256 fees);
    event LogFeeParametersChanged(address indexed feeCollector, uint16 feeAmount);
    event LogStrategyExecutorChanged(address indexed executor, bool allowed);

    // ApeCoinStaking requires at least 1 APE per deposit.
    uint256 public constant MIN_DEPOSIT = 1e18;
    uint256 public constant BIPS = 10_000;

    IApeCoinStaking public immutable staking;
    uint16 public feePercentBips;
    address public feeCollector;

    constructor(
        ERC20 __asset,
        string memory _name,
        string memory _symbol,
        IApeCoinStaking _staking
    ) {
        _asset = __asset;
        name = _name;
        symbol = _symbol;
        staking = _staking;

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
        uint256 staked = staking.stakedTotal(address(this));
        uint256 pending = staking.pendingRewards(0, address(this), 0);
        uint256 fees = (pending * feePercentBips) / BIPS;
        return balance + staked + pending - fees;
    }

    function _afterDeposit(uint256, uint256) internal override {
        harvest();
    }

    function _beforeWithdraw(uint256 assets, uint256) internal override {
        harvest();
        staking.withdrawApeCoin(assets, address(this));
    }

    function harvest() public {
        uint256 rewards = staking.pendingRewards(0, address(this), 0);

        if (rewards > 0) {
            uint256 fees = (rewards * feePercentBips) / BIPS;

            staking.claimApeCoin(address(this));
            _asset.safeTransfer(feeCollector, fees);

            emit LogHarvest(rewards, rewards - fees, fees);
        }

        uint256 balance = _asset.balanceOf(address(this));
        if (balance >= MIN_DEPOSIT) {
            staking.depositApeCoin(balance, address(this));
        }
    }
}
