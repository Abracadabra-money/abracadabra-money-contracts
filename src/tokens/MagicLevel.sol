// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/BoringOwnable.sol";
import "./ERC4626.sol";
import "interfaces/IMagicLevelRewardHandler.sol";

/// @dev see MagicGlp.sol for more details about the implementation.

contract MagicLevelData is ERC4626, BoringOwnable {
    error ErrNotStrategyExecutor(address);

    IMagicLevelRewardHandler public rewardHandler;
    mapping(address => bool) public strategyExecutors;

    modifier onlyStrategyExecutor() {
        if (msg.sender != owner && !strategyExecutors[msg.sender]) {
            revert ErrNotStrategyExecutor(msg.sender);
        }
        _;
    }
}

contract MagicLevel is MagicLevelData {
    event LogRewardHandlerChanged(IMagicLevelRewardHandler indexed previous, IMagicLevelRewardHandler indexed current);
    event LogStrategyExecutorChanged(address indexed executor, bool allowed);

    constructor(ERC20 __asset, string memory _name, string memory _symbol) {
        _asset = __asset;
        name = _name;
        symbol = _symbol;
    }

    function setStrategyExecutor(address executor, bool value) external onlyOwner {
        strategyExecutors[executor] = value;
        emit LogStrategyExecutorChanged(executor, value);
    }

    function setRewardHandler(IMagicLevelRewardHandler _rewardHandler) external onlyOwner {
        emit LogRewardHandlerChanged(rewardHandler, _rewardHandler);
        rewardHandler = _rewardHandler;
    }

    function _afterDeposit(uint256 assets, uint256 shares) internal override {
        
    }

    function _beforeWithdraw(uint256 assets, uint256 shares) internal override {
        (ILevelFinanceStaking staking, uint96 pid) = rewardHandler.stakingInfo();
    }

    fallback() external {
        _delegate(address(rewardHandler));
    }

    function _delegate(address implementation) private {
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }
}
