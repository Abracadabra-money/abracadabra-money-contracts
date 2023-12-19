// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {OperatableV2} from "mixins/OperatableV2.sol";
import {ILzFeeHandler, ILzOFTV2} from "interfaces/ILayerZero.sol";
import {IAggregator} from "interfaces/IAggregator.sol";

contract LzOFTV2FeeHandler is OperatableV2, ILzFeeHandler {
    event LogFeeWithdrawn(address to, uint256 amount);
    event LogFixedNativeFeeChanged(uint256 previous, uint256 current);
    event LogOracleImplementationChange(IAggregator indexed previous, IAggregator indexed current);
    event LogQuoteTypeChanged(QuoteType previous, QuoteType current);
    event LogFeeToChanged(address indexed previous, address indexed current);
    event LogUsdFeeChanged(uint256 previous, uint256 current);
    event LogFeeCollected(uint256 amount);

    error ErrInvalidQuoteType(QuoteType);
    error ErrWithdrawFailed();
    error ErrValueTooLowToCoverFees(uint256);
    error ErrUnauthorizedSender();

    modifier onlyFromOFT() {
        if (msg.sender != address(oft)) {
            revert ErrUnauthorizedSender();
        }
        _;
    }

    uint256 public constant DEFAULT_USD_FEE = 1e18;

    ILzOFTV2 public immutable oft;

    address public feeTo;
    IAggregator public aggregator;
    uint256 public fixedNativeFee;
    uint256 public usdFee;
    QuoteType public quoteType = QuoteType.Oracle;

    constructor(
        address _owner,
        uint256 _fixedNativeFee,
        address _oft,
        address _aggregator,
        address _feeTo,
        uint8 _quoteType
    ) OperatableV2(_owner) {
        fixedNativeFee = _fixedNativeFee;
        oft = ILzOFTV2(_oft);
        aggregator = IAggregator(_aggregator);
        feeTo = _feeTo;
        quoteType = QuoteType(_quoteType);
        usdFee = DEFAULT_USD_FEE;
    }

    receive() external payable {
        emit LogFeeCollected(msg.value);
    }

    /************************************************************************
     * Public
     ************************************************************************/
    function withdrawFees() external {
        uint256 balance = address(this).balance;
        (bool success, ) = feeTo.call{value: balance}("");
        if (!success) revert ErrWithdrawFailed();
        emit LogFeeWithdrawn(feeTo, balance);
    }

    /************************************************************************
     * Operations
     ************************************************************************/
    function setFixedNativeFee(uint256 _fixedNativeFee) external onlyOperators {
        emit LogFixedNativeFeeChanged(fixedNativeFee, _fixedNativeFee);
        fixedNativeFee = _fixedNativeFee;
    }

    function setAggregator(IAggregator _aggregator) external onlyOperators {
        emit LogOracleImplementationChange(aggregator, _aggregator);
        aggregator = _aggregator;
    }

    function setUsdFee(uint256 _usdFee) external onlyOperators {
        emit LogUsdFeeChanged(usdFee, _usdFee);
        usdFee = _usdFee;
    }

    function setQuoteType(QuoteType _quoteType) external onlyOperators {
        if (_quoteType > QuoteType.Fixed) {
            revert ErrInvalidQuoteType(_quoteType);
        }

        emit LogQuoteTypeChanged(quoteType, _quoteType);
        quoteType = _quoteType;
    }

    /************************************************************************
     * Owners
     ************************************************************************/
    function setFeeTo(address _feeTo) external onlyOwner {
        emit LogFeeToChanged(feeTo, _feeTo);
        feeTo = _feeTo;
    }

    /************************************************************************
     * Views
     ************************************************************************/
    function getFee() public view override returns (uint256 nativeFee) {
        if (quoteType == QuoteType.Oracle) {
            nativeFee = ((10 ** aggregator.decimals()) * usdFee) / uint256(aggregator.latestAnswer());
        } else if (quoteType == QuoteType.Fixed) {
            nativeFee = fixedNativeFee;
        }
    }
}
