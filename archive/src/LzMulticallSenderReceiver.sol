// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {LzNonblockingApp} from "mixins/LzNonblockingApp.sol";
import {OperatableV3} from "mixins/OperatableV3.sol";
import {Address} from "openzeppelin-contracts/utils/Address.sol";

/// @notice A contract that sends and receive calls to and from other chains.
contract LzMulticallSenderReceiver is LzNonblockingApp, OperatableV3 {
    struct Call {
        address to;
        uint256 value;
        bytes data;
    }

    event LogSent(uint16 indexed _chainId, Call[] calls);
    event LogReceived(uint16 indexed _srcChainId, Call[] calls);
    event LogNonceExpired(uint16 indexed _chainId, uint64 indexed _nonce);

    error ErrArrayLengthMismatch();

    mapping(uint16 chainid => uint64 nonce) public noncePerChain;

    constructor(address _lzEndpoint, address _owner) LzNonblockingApp(_lzEndpoint, _owner) {}

    function send(uint16 _chainId, Call[] memory _calls) external payable onlyOperators {
        _lzSend(_chainId, abi.encode(_calls), payable(msg.sender), address(0), bytes(""), msg.value);
        emit LogSent(_chainId, _calls);
    }

    function multisend(uint16[] calldata _chainIds, Call[][] memory _calls, uint256[] memory _nativeFees) external payable onlyOperators {
        if (_chainIds.length != _calls.length) {
            revert ErrArrayLengthMismatch();
        }

        for (uint256 i = 0; i < _calls.length; ) {
            _lzSend(_chainIds[i], abi.encode(_calls[i]), payable(msg.sender), address(0), bytes(""), _nativeFees[i]);
            emit LogSent(_chainIds[i], _calls[i]);
            unchecked {
                ++i;
            }
        }
    }

    function _nonblockingLzReceive(uint16 _srcChainId, bytes memory, uint64 nonce, bytes memory _payload, bool) internal override {
        if (nonce < noncePerChain[_srcChainId]) {
            emit LogNonceExpired(_srcChainId, nonce);
            return;
        }

        Call[] memory _calls = abi.decode(_payload, (Call[]));
        for (uint256 i = 0; i < _calls.length; ) {
            Address.functionCallWithValue(_calls[i].to, _calls[i].data, _calls[i].value);
            unchecked {
                ++i;
            }
        }

        emit LogReceived(_srcChainId, _calls);
    }

    function isOwner(address _account) internal view override returns (bool) {
        return _account == owner;
    }
}
