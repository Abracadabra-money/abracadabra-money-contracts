// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ERC20} from "BoringSolidity/ERC20.sol";
import {Proxy} from "openzeppelin-contracts/proxy/Proxy.sol";
import {Address} from "openzeppelin-contracts/utils/Address.sol";
import {ERC4626} from "./ERC4626.sol";
import {IMagicCurveLpRewardHandler} from "interfaces/IMagicCurveLpRewardHandler.sol";
import {Operatable} from "mixins/Operatable.sol";

contract MagicCurveLpData is ERC4626, Operatable {
    error ErrPrivateFunction();
    IMagicCurveLpRewardHandler public rewardHandler;
}

contract MagicCurveLp is MagicCurveLpData, Proxy {
    using Address for address;

    event LogRewardHandlerChanged(IMagicCurveLpRewardHandler indexed previous, IMagicCurveLpRewardHandler indexed current);

    constructor(ERC20 __asset, string memory _name, string memory _symbol) {
        _asset = __asset;
        name = _name;
        symbol = _symbol;
    }

    function setRewardHandler(IMagicCurveLpRewardHandler _rewardHandler) external onlyOwner {
        emit LogRewardHandlerChanged(rewardHandler, _rewardHandler);
        rewardHandler = _rewardHandler;
    }

    function _afterDeposit(uint256 assets, uint256 /* shares */) internal override {
        address(rewardHandler).functionDelegateCall(abi.encodeWithSelector(IMagicCurveLpRewardHandler.stakeAsset.selector, assets));
    }

    function _beforeWithdraw(uint256 assets, uint256 /* shares */) internal override {
        address(rewardHandler).functionDelegateCall(abi.encodeWithSelector(IMagicCurveLpRewardHandler.unstakeAsset.selector, assets));
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
