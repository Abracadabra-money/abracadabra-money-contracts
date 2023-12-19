// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC165} from "openzeppelin-contracts/utils/introspection/IERC165.sol";
import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {ILzOFTV2, ILzFeeHandler} from "interfaces/ILayerZero.sol";
import {LzOFTCoreV2} from "tokens/LzOFTCoreV2.sol";
import {ERC165} from "openzeppelin-contracts/utils/introspection/ERC165.sol";
import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";

abstract contract LzBaseOFTV2 is LzOFTCoreV2, ERC165, ReentrancyGuard, ILzOFTV2 {
    using SafeERC20 for IERC20;

    error ErrFeeCollectingFailed();

    event LogFeeHandlerChanged(ILzFeeHandler previous, ILzFeeHandler current);

    ILzFeeHandler public feeHandler;

    constructor(uint8 _sharedDecimals, address _lzEndpoint, address _owner) LzOFTCoreV2(_sharedDecimals, _lzEndpoint, _owner) {}

    /************************************************************************
     * public functions
     ************************************************************************/
    function sendFrom(
        address _from,
        uint16 _dstChainId,
        bytes32 _toAddress,
        uint _amount,
        LzCallParams calldata _callParams
    ) public payable virtual override nonReentrant {
        uint _valueAfterFees = _handleFees();

        _send(
            _from,
            _dstChainId,
            _toAddress,
            _amount,
            _callParams.refundAddress,
            _callParams.zroPaymentAddress,
            _callParams.adapterParams,
            _valueAfterFees
        );
    }

    function sendAndCall(
        address _from,
        uint16 _dstChainId,
        bytes32 _toAddress,
        uint _amount,
        bytes calldata _payload,
        uint64 _dstGasForCall,
        LzCallParams calldata _callParams
    ) public payable virtual override nonReentrant {
        uint _valueAfterFees = _handleFees();

        _sendAndCall(
            _from,
            _dstChainId,
            _toAddress,
            _amount,
            _payload,
            _dstGasForCall,
            _callParams.refundAddress,
            _callParams.zroPaymentAddress,
            _callParams.adapterParams,
            _valueAfterFees
        );
    }

    function _handleFees() internal returns (uint256 adjustedValue) {
        adjustedValue = msg.value;

        if (address(feeHandler) != address(0)) {
            uint256 fee = feeHandler.getFee();

            // let it revert when the value is not enough to cover the fees
            adjustedValue -= fee;

            // collect the native fee, calling the `receive` function on the fee handler
            (bool success, ) = address(feeHandler).call{value: fee}("");
            if (!success) {
                revert ErrFeeCollectingFailed();
            }
        }
    }

    /************************************************************************
     * public view functions
     ************************************************************************/
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(ILzOFTV2).interfaceId || super.supportsInterface(interfaceId);
    }

    function estimateSendFee(
        uint16 _dstChainId,
        bytes32 _toAddress,
        uint _amount,
        bool _useZro,
        bytes calldata _adapterParams
    ) public view virtual override returns (uint nativeFee, uint zroFee) {
        (nativeFee, zroFee) = _estimateSendFee(_dstChainId, _toAddress, _amount, _useZro, _adapterParams);
        if (address(feeHandler) != address(0)) {
            nativeFee += feeHandler.getFee();
        }
    }

    function estimateSendAndCallFee(
        uint16 _dstChainId,
        bytes32 _toAddress,
        uint _amount,
        bytes calldata _payload,
        uint64 _dstGasForCall,
        bool _useZro,
        bytes calldata _adapterParams
    ) public view virtual override returns (uint nativeFee, uint zroFee) {
        (nativeFee, zroFee) = _estimateSendAndCallFee(_dstChainId, _toAddress, _amount, _dstGasForCall, _payload, _useZro, _adapterParams);
        if (address(feeHandler) != address(0)) {
            nativeFee += feeHandler.getFee();
        }
    }

    function circulatingSupply() public view virtual override returns (uint);

    function token() public view virtual override returns (address);

    function setFeeHandler(ILzFeeHandler _feeHandler) public virtual onlyOwner {
        emit LogFeeHandlerChanged(feeHandler, _feeHandler);
        feeHandler = _feeHandler;
    }
}
