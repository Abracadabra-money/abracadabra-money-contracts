// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {ILzCommonOFT} from "interfaces/ILayerZero.sol";
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

    constructor(
        uint256 _defaultExchangeRate,
        address _oft,
        address _multisig,
        address governor_
    ) OFTWrapper(_defaultExchangeRate, _oft, address(0), _multisig) {
        BlastYields.configureDefaultClaimables(governor_);
    }

    function sendOFTV2(
        uint16 _dstChainId,
        bytes32 _toAddress,
        uint256 _amount,
        ILzCommonOFT.LzCallParams calldata _callParams
    ) public payable override nonReentrant handleTransit {
        super.sendOFTV2(_dstChainId, _toAddress, _handleFees(msg.sender, _amount), _callParams);
    }

    function sendProxyOFTV2(
        uint16 _dstChainId,
        bytes32 _toAddress,
        uint256 _amount,
        ILzCommonOFT.LzCallParams calldata _callParams
    ) public payable override nonReentrant handleTransit {
        super.sendProxyOFTV2(_dstChainId, _toAddress, _handleFees(msg.sender, _amount), _callParams);
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
    error ErrZeroAddress();
    error ErrNotFromWrapper();

    BlastLzOFTV2Wrapper public immutable oftWrapper;

    constructor(
        address _owner,
        uint256 _fixedNativeFee,
        address _oft,
        address _aggregator,
        address _feeTo,
        uint8 _quoteType,
        address governor_,
        BlastLzOFTV2Wrapper _oftWrapper
    ) LzOFTV2FeeHandler(_owner, _fixedNativeFee, _oft, _aggregator, _feeTo, _quoteType) {
        if (governor_ == address(0)) {
            revert ErrZeroAddress();
        }

        BlastYields.configureDefaultClaimables(governor_);

        oftWrapper = _oftWrapper;
    }

    // The oft wrapper cannot be bridged directly and must
    // go through the OFTWrapper.
    function getFee() public view override returns (uint256) {
        if (!oftWrapper.inTransit()) {
            revert ErrNotFromWrapper();
        }

        return super.getFee();
    }
}
