// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {ILzCommonOFT, ILzBaseOFTV2, ILzFeeHandler, ILzEndpoint, ILzApp, ILzIndirectOFTV2} from "interfaces/ILayerZero.sol";
import {LzOFTV2FeeHandler} from "periphery/LzOFTV2FeeHandler.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {BlastYields} from "/blast/libraries/BlastYields.sol";
import {OFTWrapper} from "mixins/OFTWrapper.sol";
import {FeeCollectable} from "mixins/FeeCollectable.sol";

contract BlastLzOFTV2Wrapper is OFTWrapper, FeeCollectable {
    using SafeTransferLib for address;

    bool public inTransit;

    mapping(address => bool) public noFeeWhitelist;

    event LogFeeCollected(uint256 amount);
    event LogNoFeeWhitelist(address account, bool noFee);

    modifier handleTransit() {
        inTransit = true;
        _;
        inTransit = false;
    }

    constructor(address _oft, address _owner, address _governor) OFTWrapper(0, _oft, address(0), _owner) {
        BlastYields.configureDefaultClaimables(_governor);
    }

    function sendOFTV2(
        uint16 _dstChainId,
        bytes32 _toAddress,
        uint256 _amount,
        ILzCommonOFT.LzCallParams calldata _callParams
    ) public payable override nonReentrant handleTransit {
        _sendOFTV2(_dstChainId, _toAddress, _handleFees(msg.sender, _amount), _callParams);
    }

    function sendProxyOFTV2(
        uint16 _dstChainId,
        bytes32 _toAddress,
        uint256 _amount,
        ILzCommonOFT.LzCallParams calldata _callParams
    ) public payable override nonReentrant handleTransit {
        _sendProxyOFTV2(_dstChainId, _toAddress, _handleFees(msg.sender, _amount), _callParams);
    }

    /// @dev override estimateSendFeeV2 to byepass the transit check.
    function estimateSendFeeV2(
        uint16 _dstChainId,
        bytes32 _toAddress,
        uint256 _amount,
        bytes calldata _adapterParams
    ) public view override returns (uint nativeFee, uint zroFee) {
        uint _amountSD = _amount / ILzIndirectOFTV2(address(oft)).ld2sdRate();
        require(_amountSD <= type(uint64).max);

        bytes memory payload = abi.encodePacked(uint8(0), _toAddress, uint64(_amountSD));
        ILzEndpoint lzEndpoint = ILzEndpoint(ILzApp(address(oft)).lzEndpoint());
        (nativeFee, zroFee) = lzEndpoint.estimateFees(_dstChainId, address(oft), payload, false, _adapterParams);

        ILzFeeHandler feeHandler = ILzBaseOFTV2(address(oft)).feeHandler();
        if (address(feeHandler) != address(0)) {
            nativeFee += BlastLzOFTV2FeeHandler(payable(address(feeHandler))).getFeeNoTransitCheck();
        }
    }

    function isFeeOperator(address account) public view override returns (bool) {
        return owner == account;
    }

    function _handleFees(address account, uint256 amount) internal returns (uint256 amountAfterFees) {
        if (noFeeWhitelist[account]) {
            return amount;
        }

        uint256 feeAmount;
        (amountAfterFees, feeAmount) = calculateFees(amount);
        token.safeTransferFrom(msg.sender, feeCollector, feeAmount);

        if (feeAmount > 0) {
            emit LogFeeCollected(feeAmount);
        }
    }

    function setNoFeeWhitelist(address account, bool noFee) public onlyOwner {
        noFeeWhitelist[account] = noFee;
        emit LogNoFeeWhitelist(account, noFee);
    }
}

/// @dev This contract holds ETH from fees and accumulates
/// ETH yields to claim.
contract BlastLzOFTV2FeeHandler is LzOFTV2FeeHandler {
    event LogNoTransitCheckWhitelist(address account, bool noCheck);

    error ErrZeroAddress();
    error ErrNotFromWrapper();

    BlastLzOFTV2Wrapper public immutable oftWrapper;
    mapping(address => bool) public noTransitCheckWhitelist;

    constructor(
        address _owner,
        uint256 _fixedNativeFee,
        address _oft,
        address _aggregator,
        address _feeTo,
        uint8 _quoteType,
        address _governor,
        BlastLzOFTV2Wrapper _oftWrapper
    ) LzOFTV2FeeHandler(_owner, _fixedNativeFee, _oft, _aggregator, _feeTo, _quoteType) {
        if (_governor == address(0)) {
            revert ErrZeroAddress();
        }

        BlastYields.configureDefaultClaimables(_governor);

        oftWrapper = _oftWrapper;
    }

    // The oft wrapper cannot be bridged directly and must
    // go through the OFTWrapper.
    function getFee() public view override returns (uint256) {
        if (!noTransitCheckWhitelist[msg.sender] && !oftWrapper.inTransit()) {
            revert ErrNotFromWrapper();
        }
        return super.getFee();
    }

    function getFeeNoTransitCheck() public view returns (uint256) {
        return super.getFee();
    }

    function setNoTransitCheckWhitelist(address account, bool noCheck) public onlyOwner {
        noTransitCheckWhitelist[account] = noCheck;
        emit LogNoTransitCheckWhitelist(account, noCheck);
    }
}