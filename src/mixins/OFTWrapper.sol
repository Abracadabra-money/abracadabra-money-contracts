// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ReentrancyGuard} from "openzeppelin-contracts/security/ReentrancyGuard.sol";
import {OperatableV2} from "mixins/OperatableV2.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ILzOFTV2, IOFTWrapper, ILzApp, ILzCommonOFT, ILzEndpoint} from "interfaces/ILayerZero.sol";
import {IAggregator} from "interfaces/IAggregator.sol";
import "forge-std/console2.sol";

contract OFTWrapper is IOFTWrapper, OperatableV2, ReentrancyGuard {
    using SafeTransferLib for address;

    error ErrInvalidQuoteType(QUOTE_TYPE);
    error ErrWithdrawFailed();
    error ErrZeroAddress();
    error ErrMessageValueIsLow(uint256);
    error ErrInvalidAddress();

    ILzOFTV2 public immutable oft;
    address public immutable token;

    address public feeTo;
    IAggregator public aggregator;
    uint256 public defaultFee;
    QUOTE_TYPE public defaultQuoteType;

    constructor(uint256 _defaultFee, address _oft, address _aggregator, address _owner) OperatableV2(_owner) {
        if (_oft == address(0)) {
            revert ErrZeroAddress();
        }

        defaultFee = _defaultFee;
        oft = ILzOFTV2(_oft);
        token = oft.token();
        aggregator = IAggregator(_aggregator);
        token.safeApprove(address(oft), type(uint256).max);
        feeTo = _owner;

        defaultQuoteType = QUOTE_TYPE.FIXED_EXCHANGE_RATE;
    }

    ///////////////////////////////////////////////////////////////////////////
    /// Permissionless
    ///////////////////////////////////////////////////////////////////////////

    function withdrawFees() external {
        uint balance = address(this).balance;
        (bool success, ) = feeTo.call{value: balance}("");
        if (!success) revert ErrWithdrawFailed();
        emit LogWrapperFeeWithdrawn(feeTo, balance);
    }

    function sendOFTV2(
        uint16 _dstChainId,
        bytes32 _toAddress,
        uint256 _amount,
        ILzCommonOFT.LzCallParams calldata _callParams
    ) public payable virtual override nonReentrant {
        _sendOFTV2(_dstChainId, _toAddress, _amount, _callParams);
    }

    function sendProxyOFTV2(
        uint16 _dstChainId,
        bytes32 _toAddress,
        uint256 _amount,
        ILzCommonOFT.LzCallParams calldata _callParams
    ) public payable virtual override nonReentrant {
        _sendProxyOFTV2(_dstChainId, _toAddress, _amount, _callParams);
    }

    function _sendOFTV2(
        uint16 _dstChainId,
        bytes32 _toAddress,
        uint256 _amount,
        ILzCommonOFT.LzCallParams calldata _callParams
    ) internal virtual {
        uint fee = _estimateFee();

        if (msg.value < fee) {
            revert ErrMessageValueIsLow(msg.value);
        }

        uint256 val = msg.value - fee;
        oft.sendFrom{value: val}(msg.sender, _dstChainId, _toAddress, _amount, _callParams);
    }

    function _sendProxyOFTV2(
        uint16 _dstChainId,
        bytes32 _toAddress,
        uint256 _amount,
        ILzCommonOFT.LzCallParams calldata _callParams
    ) internal virtual {
        uint fee = _estimateFee();

        if (msg.value < fee) {
            revert ErrMessageValueIsLow(msg.value);
        }

        uint256 val = msg.value - fee;

        token.safeTransferFrom(msg.sender, address(this), _amount);
        oft.sendFrom{value: val}(address(this), _dstChainId, _toAddress, _amount, _callParams);
    }

    ///////////////////////////////////////////////////////////////////////////
    /// Views
    ///////////////////////////////////////////////////////////////////////////

    function estimateSendFeeV2(
        uint16 _dstChainId,
        bytes32 _toAddress,
        uint256 _amount,
        bytes calldata _adapterParams
    ) external view virtual override returns (uint nativeFee, uint zroFee) {
        (nativeFee, zroFee) = oft.estimateSendFee(_dstChainId, _toAddress, _amount, false, _adapterParams);
        nativeFee += _estimateFee();
    }

    function lzEndpoint() external view returns (ILzEndpoint) {
        return ILzApp(address(oft)).lzEndpoint();
    }

    function minDstGasLookup(uint16 _srcChainId, uint16 _dstChainId) external view returns (uint) {
        return ILzApp(address(oft)).minDstGasLookup(_srcChainId, _dstChainId);
    }

    ///////////////////////////////////////////////////////////////////////////
    /// Operators
    ///////////////////////////////////////////////////////////////////////////

    function setDefaultExchangeRate(uint256 _defaultExchangeRate) external onlyOperators {
        emit LogDefaultExchangeRateChanged(defaultFee, _defaultExchangeRate);
        defaultFee = _defaultExchangeRate;
    }

    function setAggregator(IAggregator _aggregator) external onlyOperators {
        emit LogOracleImplementationChange(aggregator, _aggregator);
        aggregator = _aggregator;
    }

    function setDefaultQuoteType(QUOTE_TYPE _quoteType) external onlyOperators {
        if (_quoteType > QUOTE_TYPE.FIXED_EXCHANGE_RATE) {
            revert ErrInvalidQuoteType(_quoteType);
        }

        emit LogDefaultQuoteTypeChanged(defaultQuoteType, _quoteType);
        defaultQuoteType = _quoteType;
    }

    ///////////////////////////////////////////////////////////////////////////
    /// Admin
    ///////////////////////////////////////////////////////////////////////////

    function setFeeTo(address _feeTo) external onlyOwner {
        if (_feeTo == address(0)) {
            revert ErrZeroAddress();
        }
        emit LogFeeToChange(feeTo, _feeTo);
        feeTo = _feeTo;
    }

    ///////////////////////////////////////////////////////////////////////////
    /// Internals
    ///////////////////////////////////////////////////////////////////////////

    function _estimateFee() internal view returns (uint256 fee) {
        if (defaultQuoteType == QUOTE_TYPE.ORACLE) {
            fee = ((10 ** aggregator.decimals()) * 1e18) / uint256(aggregator.latestAnswer());
        } else {
            fee = defaultFee;
        }
    }
}
