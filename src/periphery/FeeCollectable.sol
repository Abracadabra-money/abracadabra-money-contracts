// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/interfaces/IERC20.sol";
import "BoringSolidity/BoringOwnable.sol";

abstract contract FeeCollectable {
    error ErrInvalidFeeBips();
    error ErrInvalidFeeOperator(address);
    event LogFeeParametersChanged(
        address indexed previousFeeCollector,
        uint16 previousFeeAmount,
        address indexed feeCollector,
        uint16 feeAmount
    );

    uint256 private constant BIPS = 10_000;

    uint16 public feeBips;
    address public feeCollector;

    modifier onlyAllowedFeeOperator() {
        if (!isFeeOperator(msg.sender)) {
            revert ErrInvalidFeeOperator(msg.sender);
        }
        _;
    }

    function setFeeParameters(address _feeCollector, uint16 _feeBips) external onlyAllowedFeeOperator {
        if (feeBips > BIPS) {
            revert ErrInvalidFeeBips();
        }

        emit LogFeeParametersChanged(feeCollector, feeBips, _feeCollector, _feeBips);

        feeCollector = _feeCollector;
        feeBips = _feeBips;
    }

    function calculateFees(uint256 amountIn) internal view returns (uint userAmount, uint feeAmount) {
        feeAmount = (amountIn * feeBips) / BIPS;
        userAmount = amountIn - feeAmount;
    }

    function isFeeOperator(address account) public virtual returns (bool);
}
