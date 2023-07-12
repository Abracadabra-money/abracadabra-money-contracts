// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {BaseOFTV2View} from "periphery/precrime/BaseOFTV2View.sol";
import {LzProxyOFTV2} from "tokens/LzProxyOFTV2.sol";

contract IndirectOFTV2View is BaseOFTV2View {
    constructor(address _oft) BaseOFTV2View(_oft) {}

    function lzReceive(
        uint16 _srcChainId,
        bytes32 _scrAddress,
        bytes memory _payload,
        uint _totalSupply
    ) external view override returns (uint) {
        if (!_isPacketFromTrustedRemote(_srcChainId, _scrAddress)) {
            revert ErrNotTrustedRemote();
        }
    
        uint amount = _decodePayload(_payload);
        return _totalSupply + amount;
    }

    function isProxy() external pure override returns (bool) {
        return false;
    }

    function getCurrentState() external view override returns (uint) {
        return token.totalSupply();
    }
}
