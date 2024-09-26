// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {ILzOFTV2, ILzApp, ILzBaseOFTV2, ILzCommonOFT, ILzOFTReceiverV2} from "@abracadabra-oftv2/interfaces/ILayerZero.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {Ownable} from "@solady/auth/Ownable.sol";

contract LzSender is Ownable {
    using SafeTransferLib for address;

    uint16 public constant LZ_HUB_CHAIN_ID = 110; // Arbitrum

    // packet type
    uint8 public constant PT_SEND = 0;
    uint8 public constant PT_SEND_AND_CALL = 1;

    address public immutable spellV2;
    ILzOFTV2 public immutable spellOft;

    mapping(uint256 => uint64) public gasPerAction;

    constructor(ILzOFTV2 _spellOft, address _owner) {
        spellOft = _spellOft;
        spellV2 = ILzBaseOFTV2(address(_spellOft)).innerToken();

        gasPerAction[0] = 100_000;

        _initializeOwner(_owner);
    }

    function estimate(uint256 action) external view returns (uint256 /*fee*/, uint256 /*unused*/) {
        bytes memory payload = abi.encode(action, msg.sender);
        uint256 minGas = ILzApp(address(spellOft)).minDstGasLookup(LZ_HUB_CHAIN_ID, 1);
        uint64 dstGasForCall = gasPerAction[action];

        return
            spellOft.estimateSendAndCallFee(
                LZ_HUB_CHAIN_ID,
                bytes32(uint256(uint160(address(this)))), // Destination address (same as this contract)
                1, // amount - no need to estimate
                payload,
                dstGasForCall,
                false,
                abi.encodePacked(uint16(1), minGas + dstGasForCall) // must include minGas + dstGasForCall
            );
    }

    function send(uint8 action, uint256 _amount) external payable {
        bytes memory payload = abi.encode(action, msg.sender);
        uint256 minGas = ILzApp(address(spellOft)).minDstGasLookup(LZ_HUB_CHAIN_ID, 1);
        uint64 dstGasForCall = gasPerAction[action];

        spellV2.safeTransferFrom(msg.sender, address(this), _amount);

        spellOft.sendAndCall{value: msg.value}(
            address(this), // From address
            LZ_HUB_CHAIN_ID, // Destination chain ID
            bytes32(uint256(uint160(address(this)))), // Destination address (same as this contract)
            _amount,
            payload,
            dstGasForCall,
            ILzCommonOFT.LzCallParams(
                payable(address(msg.sender)), // Refund address
                address(0), // ZRO payment address (not used)
                abi.encodePacked(uint16(1), minGas + dstGasForCall) // must include minGas + dstGasForCall
            )
        );
    }

    function setGasPerAction(uint256 action, uint64 gas) external onlyOwner {
        gasPerAction[action] = gas;
    }
}

contract LzReceiver is ILzOFTReceiverV2 {
    using SafeTransferLib for address;

    error ErrInvalidSender();
    error ErrInvalidSourceChainId();
    error ErrInvalidAction();

    uint16 internal constant LzArbitrumChainId = 110;

    address public immutable spellV2;
    ILzOFTV2 public immutable spellOft;
    bytes32 public immutable remoteSender = bytes32(uint256(uint160(address(this))));

    constructor(ILzOFTV2 _spellOft) {
        spellOft = _spellOft;
        spellV2 = ILzBaseOFTV2(address(_spellOft)).innerToken();
    }

    function onOFTReceived(
        uint16 _srcChainId, // Any chains except Arbitrum
        bytes calldata, // [ignored] _srcAddress: Remote OFT, using msg.sender against local oft to validate instead
        uint64, // [ignored] _nonce
        bytes32 _from, // BoundSpellActionSender
        uint256 _amount,
        bytes calldata _payload
    ) external override {
        (uint8 action, address user) = abi.decode(_payload, (uint8, address));

        if (_srcChainId == LzArbitrumChainId) {
            revert ErrInvalidSourceChainId();
        }
        if (_from != remoteSender) {
            revert ErrInvalidSender();
        }
        if (msg.sender == address(spellOft)) {
            if (action == 0) {
                spellV2.safeTransfer(user, _amount);
            } else {
                revert ErrInvalidAction();
            }
        } else {
            revert ErrInvalidSender();
        }
    }
}
