// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ReentrancyGuard} from "openzeppelin-contracts/security/ReentrancyGuard.sol";
import {OperatableV2} from "mixins/OperatableV2.sol";
import {IERC20, SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {ILzOFTV2, IOFTWrapper, ILzApp, ILzCommonOFT, ILzEndpoint} from "interfaces/ILayerZero.sol";
import {IAggregator} from "interfaces/IAggregator.sol";

contract OFTWrapper is IOFTWrapper, OperatableV2, ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public feeTo;
    IAggregator public aggregator;
    ILzOFTV2 public immutable oft;
    IERC20 public immutable token;

    uint256 public defaultExchangeRate;
    QUOTE_TYPE public defaultQuoteType = QUOTE_TYPE.FIXED_EXCHANGE_RATE;

    error InvalidQuoteType(QUOTE_TYPE);
    error ErrWithdrawFailed();
    error MessageValueIsLow(uint256);
    error InvalidAddress();

    constructor(uint256 _defaultExchangeRate, address _oft, address _aggregator, address _multisig) OperatableV2(_multisig) {
        defaultExchangeRate = _defaultExchangeRate;
        require(_oft != address(0), "OFTWrapper: invalid oft");
        oft = ILzOFTV2(_oft);
        token = IERC20(oft.token());
        require(_aggregator != address(0), "OFTWrapper: invalid aggregator");
        aggregator = IAggregator(_aggregator);
        token.safeApprove(address(oft), type(uint256).max);
        feeTo = _multisig;
    }

    function setDefaultExchangeRate(uint256 _defaultExchangeRate) external onlyOperators {
        emit LogDefaultExchangeRateChanged(defaultExchangeRate, _defaultExchangeRate);
        defaultExchangeRate = _defaultExchangeRate;
    }

    function setAggregator(IAggregator _aggregator) external onlyOperators {
        if (address(_aggregator) == address(0)) revert InvalidAddress();
        emit LogOracleImplementationChange(aggregator, _aggregator);
        aggregator = _aggregator;
    }

    function setDefaultQuoteType(QUOTE_TYPE _quoteType) external onlyOperators {
        if (_quoteType > QUOTE_TYPE.FIXED_EXCHANGE_RATE) revert InvalidQuoteType(_quoteType);
        emit LogDefaultQuoteTypeChanged(defaultQuoteType, _quoteType);
        defaultQuoteType = _quoteType;
    }

    function setFeeTo(address _feeTo) external onlyOwner {
        if (_feeTo == address(0)) revert InvalidAddress();
        emit LogFeeToChange(feeTo, _feeTo);
        feeTo = _feeTo;
    }

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
    ) external payable override nonReentrant {
        uint fee = _estimateFee();
        if (msg.value < fee) revert MessageValueIsLow(msg.value);
        uint256 val = msg.value - fee;
        oft.sendFrom{value: val}(msg.sender, _dstChainId, _toAddress, _amount, _callParams);
    }

    function sendProxyOFTV2(
        uint16 _dstChainId,
        bytes32 _toAddress,
        uint256 _amount,
        ILzCommonOFT.LzCallParams calldata _callParams
    ) external payable override nonReentrant {
        uint fee = _estimateFee();
        if (msg.value < fee) revert MessageValueIsLow(msg.value);
        uint256 val = msg.value - fee;
        token.safeTransferFrom(msg.sender, address(this), _amount);
        oft.sendFrom{value: val}(address(this), _dstChainId, _toAddress, _amount, _callParams);
    }

    function estimateSendFeeV2(
        uint16 _dstChainId,
        bytes32 _toAddress,
        uint256 _amount,
        bytes calldata _adapterParams
    ) external view override returns (uint nativeFee, uint zroFee) {
        (nativeFee, zroFee) = oft.estimateSendFee(_dstChainId, _toAddress, _amount, false, _adapterParams);
        nativeFee += _estimateFee();
    }

    function _estimateFee() internal view returns (uint256 fee) {
        if (defaultQuoteType == QUOTE_TYPE.ORACLE) {
            fee = ((10 ** aggregator.decimals()) * 1e18) / uint256(aggregator.latestAnswer());
        } else {
            fee = defaultExchangeRate;
        }
    }

    function lzEndpoint() external view returns (ILzEndpoint) {
        return ILzApp(address(oft)).lzEndpoint();
    }

    function minDstGasLookup(uint16 _srcChainId, uint16 _dstChainId) external view returns (uint) {
        return ILzApp(address(oft)).minDstGasLookup(_srcChainId, _dstChainId);
    }
}
