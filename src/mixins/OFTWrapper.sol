// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "openzeppelin-contracts/security/ReentrancyGuard.sol";
import "openzeppelin-contracts/access/Ownable.sol";
import "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "layerzerolabs-solidity-examples/token/oft/v2/IOFTV2.sol";
import "layerzerolabs-solidity-examples/token/oft/IOFT.sol";
import "interfaces/IOFTWrapper.sol";
import "interfaces/IAggregator.sol";

contract OFTWrapper is IOFTWrapper, Ownable, ReentrancyGuard {
    using SafeERC20 for IOFT;

    IAggregator public aggregator;
    IOFTV2 public immutable oft;
    IOFT public immutable token;

    uint256 public defaultExchangeRate;

    error InvalidQuoteType();

    constructor(uint256 _defaultExchangeRate, address _oft, address _aggregator, address _multisig) {
        defaultExchangeRate = _defaultExchangeRate;
        require(_oft != address(0), "OFTWrapper: invalid oft");
        oft = IOFTV2(_oft);
        token = IOFT(oft.token());
        require(_aggregator != address(0), "OFTWrapper: invalid aggregator");
        aggregator = IAggregator(_aggregator);
        transferOwnership(_multisig);
    }

    function setDefaultExchangeRate(uint256 _defaultExchangeRate) external onlyOwner {
        defaultExchangeRate = _defaultExchangeRate;
    }

    function setAggregator(address _aggregator) external onlyOwner {

    }
    function withdrawFees(address _to, uint256 _amount) external onlyOwner {
        (bool success, ) = _to.call{value: _amount}(new bytes(0));
        require(success, 'STE');
        emit WrapperFeeWithdrawn(_to, _amount);
    }

    function sendOFTV2(
        uint16 _dstChainId,
        bytes32 _toAddress,
        uint256 _amount,
        QUOTE_TYPE _quote_type,
        IOFTV2.LzCallParams calldata _callParams
    ) external payable nonReentrant {
        uint256 val = msg.value - _estimateFee(_quote_type);
        oft.sendFrom{ value: val }(
            msg.sender,
            _dstChainId,
            _toAddress,
            _amount,
            _callParams
        );
    }

    function sendProxyOFTV2(
        uint16 _dstChainId,
        bytes32 _toAddress,
        uint256 _amount,
        QUOTE_TYPE _quote_type,
        IOFTV2.LzCallParams calldata _callParams
    ) external payable nonReentrant {
        uint256 val = msg.value - _estimateFee(_quote_type);
        token.safeTransferFrom(msg.sender, address(this), _amount);
        // approve proxy to spend tokens
        token.safeApprove(address(oft), _amount);
        oft.sendFrom{ value: val }(
            address(this),
            _dstChainId,
            _toAddress,
            _amount,
            _callParams
        );

        // reset allowance if sendFrom() does not consume full amount
        if (token.allowance(address(this), address(oft)) > 0)
            token.safeApprove(address(oft), 0);
    }

    function estimateSendFeeV2(
        uint16 _dstChainId,
        bytes32 _toAddress,
        uint256 _amount,
        bool _useZro,
        QUOTE_TYPE _quote_type,
        bytes calldata _adapterParams
    ) external view override returns (uint nativeFee, uint zroFee) {

        (nativeFee, zroFee) = oft.estimateSendFee(_dstChainId, _toAddress, _amount, _useZro, _adapterParams);
        nativeFee += _estimateFee(_quote_type);
            
    }

    function _estimateFee(QUOTE_TYPE _quote_type) internal view returns (uint256 fee) {
        if (_quote_type == QUOTE_TYPE.ORACLE) {
            fee = aggregator.decimals() * 1e18 / uint256(aggregator.latestAnswer());
        } else if (_quote_type == QUOTE_TYPE.FIXED_EXCHANGE_RATE) {
            fee = defaultExchangeRate;
        } else {
            revert InvalidQuoteType();
        }
    }
}
