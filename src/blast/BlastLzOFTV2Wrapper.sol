// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {ILzCommonOFT, ILzBaseOFTV2, ILzFeeHandler, ILzEndpoint, ILzApp, ILzIndirectOFTV2} from "/interfaces/ILayerZero.sol";
import {LzOFTV2FeeHandler} from "/periphery/LzOFTV2FeeHandler.sol";
import {BlastYields} from "/blast/libraries/BlastYields.sol";
import {OFTWrapper} from "/mixins/OFTWrapper.sol";
import {FeeCollectable} from "/mixins/FeeCollectable.sol";
import {IBlastLzOFTV2FeeHandler} from "/blast/interfaces/IBlastLzOFTV2FeeHandler.sol";
import {IBlastLzOFTV2Wrapper} from "/blast/interfaces/IBlastLzOFTV2Wrapper.sol";

contract BlastLzOFTV2Wrapper is OFTWrapper, FeeCollectable, IBlastLzOFTV2Wrapper {
    using SafeTransferLib for address;

    bool private _inTransit;

    mapping(address => bool) public noFeeWhitelist;

    event LogFeeCollected(uint256 amount);
    event LogNoFeeWhitelist(address account, bool noFee);

    modifier handleTransit() {
        _inTransit = true;
        _;
        _inTransit = false;
    }

    constructor(address _oft, address _owner, address _governor) OFTWrapper(0, _oft, address(0), _owner) {
        BlastYields.configureDefaultClaimables(_governor);
    }

    ////////////////////////////////////////////////////////////////////
    /// Permissionless
    ////////////////////////////////////////////////////////////////////

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

    ////////////////////////////////////////////////////////////////////
    /// Views
    ////////////////////////////////////////////////////////////////////

    function inTransit() public view override returns (bool) {
        return _inTransit;
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
            nativeFee += IBlastLzOFTV2FeeHandler(payable(address(feeHandler))).getFeeNoTransitCheck();
        }
    }

    function isFeeOperator(address account) public view override returns (bool) {
        return owner == account;
    }

    ////////////////////////////////////////////////////////////////////
    /// Internals
    ////////////////////////////////////////////////////////////////////

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

    ////////////////////////////////////////////////////////////////////
    /// Admin
    ////////////////////////////////////////////////////////////////////

    function setNoFeeWhitelist(address account, bool noFee) external onlyOwner {
        noFeeWhitelist[account] = noFee;
        emit LogNoFeeWhitelist(account, noFee);
    }
}
