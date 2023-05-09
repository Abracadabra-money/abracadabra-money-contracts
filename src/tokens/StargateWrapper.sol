// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/BoringOwnable.sol";
import "BoringSolidity/libraries/BoringERC20.sol";
import "./ERC4626.sol";
import "interfaces/ILPStaking.sol";
import "mixins/FeeCollectable.sol";

contract StargateWrapper is ERC4626, BoringOwnable, FeeCollectable {
    using BoringERC20 for ERC20;

    event LogHarvest(uint256 totalRewards, uint256 userRewards, uint256 fees);

    uint256 public constant BIPS = 10_000;
    uint256 public immutable pid;
    ERC20 public immutable reward;
    ILPStaking public immutable staking;

    constructor(ERC20 __asset, ERC20 _reward, string memory _name, string memory _symbol, ILPStaking _staking, uint256 _pid) {
        _asset = __asset;
        reward = _reward;
        name = _name;
        symbol = _symbol;
        staking = _staking;
        pid = _pid;

        __asset.approve(address(_staking), type(uint256).max);
    }

    function isFeeOperator(address account) public view override returns (bool) {
        return account == owner;
    }

    function totalAssets() public view override returns (uint256) {
        return _asset.balanceOf(address(this));
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
        uint256 rewardAmount = reward.balanceOf(address(this));
        reward.safeTransfer(feeCollector, rewardAmount);
        
        emit LogHarvest(rewardAmount, 0, rewardAmount);
    }
}
