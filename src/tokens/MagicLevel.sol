// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "OpenZeppelin/proxy/Proxy.sol";
import "BoringSolidity/BoringOwnable.sol";
import "./ERC4626.sol";
import "interfaces/IMagicLevelRewardHandler.sol";
import "periphery/Operatable.sol";

contract MagicLevelData is ERC4626, Operatable {
    error ErrNotVault();
    IMagicLevelRewardHandler public rewardHandler;
}

contract MagicLevel is MagicLevelData, Proxy {
    event LogRewardHandlerChanged(IMagicLevelRewardHandler indexed previous, IMagicLevelRewardHandler indexed current);

    constructor(ERC20 __asset, string memory _name, string memory _symbol) {
        _asset = __asset;
        name = _name;
        symbol = _symbol;
    }

    function setRewardHandler(IMagicLevelRewardHandler _rewardHandler) external onlyOwner {
        emit LogRewardHandlerChanged(rewardHandler, _rewardHandler);
        rewardHandler = _rewardHandler;
    }

    function _afterDeposit(uint256 assets, uint256 /* shares */) internal override {
        rewardHandler.deposit(assets);
    }

    function _beforeWithdraw(uint256 assets, uint256 /* shares */) internal override {
        rewardHandler.withdraw(assets);
    }

    function _implementation() internal view override returns (address) {
        return address(rewardHandler);
    }
}
