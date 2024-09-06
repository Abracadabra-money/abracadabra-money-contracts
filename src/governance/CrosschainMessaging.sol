// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {Ownable} from "@solady/auth/Ownable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@solady/utils/UUPSUpgradeable.sol";
import {LzNonblockingApp} from "@abracadabra-oftv2/LzNonblockingApp.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

struct CallPayload {
    address to;
    bytes data;
}

struct Message {
    uint16 dstChainId;
    uint16 packetType;
    uint16 messageType;
    uint16 gasLimit;
    CallPayload payload;
    bool executed;
}

contract CrosschainMessaging is Initializable, Ownable, LzNonblockingApp {
    error ErrAlreadyExecuted();
    error ErrMessageNotSet();

    event MessageSet(Message message);
    event MessageExecuted(Message message);

    Message public message;

    constructor(address _lzEndpoint) LzNonblockingApp(_lzEndpoint) {
        _disableInitializers();
    }

    function initialize(address _owner) public initializer {
        _initializeOwner(_owner);
    }

    ////////////////////////////////////////////////////////////////////
    /// Views
    ////////////////////////////////////////////////////////////////////

    function adapterParams() public view returns (bytes memory) {
        return abi.encodePacked(message.messageType, uint256(minDstGasLookup[message.dstChainId][message.packetType]));
    }

    function estimateFees() external view returns (uint256 fee) {
        (fee, ) = lzEndpoint.estimateFees(message.dstChainId, address(this), abi.encode(message.payload), false, adapterParams());
    }

    ////////////////////////////////////////////////////////////////////
    /// Admin
    ////////////////////////////////////////////////////////////////////

    function setMessage(Message memory _message) external onlyOwner {
        message = _message;
        emit MessageSet(_message);
    }

    ////////////////////////////////////////////////////////////////////
    /// Permissionless
    ////////////////////////////////////////////////////////////////////

    function exec() external payable {
        if (message.executed) {
            revert ErrAlreadyExecuted();
        }

        if(message.dstChainId == 0) {
            revert ErrMessageNotSet();
        }

        message.executed = true;

        // TODO: validate that if this fails, this can always be retried from layerzeroscan
        _lzSend(
            message.dstChainId,
            abi.encode(message.payload),
            payable(msg.sender), // TODO: evaluate the risk or refund value to user sending this
            address(0), // unused
            adapterParams(),
            msg.value
        );

        emit MessageExecuted(message);
    }

    ////////////////////////////////////////////////////////////////////
    /// Internals
    ////////////////////////////////////////////////////////////////////

    function _nonblockingLzReceive(
        uint16 /*srcChainId */,
        bytes memory /* srcAddress */,
        uint64 /*_nonce*/,
        bytes memory _payload,
        bool /*retry*/
    ) internal virtual override {
        CallPayload memory callPayload = abi.decode(_payload, (CallPayload));
        Address.functionCall(callPayload.to, callPayload.data);
    }

    function _lzAppOwner() internal view virtual override returns (address) {
        return owner();
    }
}
