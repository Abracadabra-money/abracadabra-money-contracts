// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Proxy} from "@openzeppelin/contracts/proxy/Proxy.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ERC20} from "@BoringSolidity/ERC20.sol";
import {ERC4626} from "/tokens/ERC4626.sol";
import {IMagicJUSDCRewardHandler} from "/interfaces/IMagicJUSDCRewardHandler.sol";
import {Operatable} from "/mixins/Operatable.sol";

contract MagicJUSDCData is ERC4626, Operatable {
    error ErrPrivateFunction();
    IMagicJUSDCRewardHandler public rewardHandler;
}

contract MagicJUSDC is MagicJUSDCData, Proxy {
    using Address for address;

    event LogRewardHandlerChanged(IMagicJUSDCRewardHandler indexed previous, IMagicJUSDCRewardHandler indexed current);

    receive() external payable {}

    constructor(ERC20 __asset, string memory _name, string memory _symbol) {
        _asset = __asset;
        name = _name;
        symbol = _symbol;
    }

    function setRewardHandler(IMagicJUSDCRewardHandler _rewardHandler) external onlyOwner {
        emit LogRewardHandlerChanged(rewardHandler, _rewardHandler);
        rewardHandler = _rewardHandler;
    }

    function _afterDeposit(uint256 assets, uint256 /* shares */) internal override {
        address(rewardHandler).functionDelegateCall(abi.encodeWithSelector(IMagicJUSDCRewardHandler.stakeAsset.selector, assets));
    }

    function _beforeWithdraw(uint256 assets, uint256 /* shares */) internal override {
        address(rewardHandler).functionDelegateCall(abi.encodeWithSelector(IMagicJUSDCRewardHandler.unstakeAsset.selector, assets));
    }

    function _fallback() internal override {
        if (rewardHandler.isPrivateDelegateFunction(msg.sig)) {
            revert ErrPrivateFunction();
        }

        _delegate(_implementation());
    }

    function _implementation() internal view override returns (address) {
        return address(rewardHandler);
    }
}
