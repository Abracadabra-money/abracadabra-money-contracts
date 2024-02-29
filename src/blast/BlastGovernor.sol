// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {BlastYields} from "/blast/libraries/BlastYields.sol";
import {OperatableV2} from "mixins/OperatableV2.sol";

contract BlastGovernor is OperatableV2 {
    event LogFeeToChanged(address indexed feeTo);
    error ErrZeroAddress();
    
    address public feeTo;

    receive() external payable {}

    constructor(address feeTo_, address _owner) OperatableV2(_owner) {
        if (feeTo_ == address(0)) {
            revert ErrZeroAddress();
        }

        feeTo = feeTo_;
        BlastYields.configureDefaultClaimables(address(this));
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// OPERATORS
    //////////////////////////////////////////////////////////////////////////////////////

    function claim(address contractAddress) external onlyOperators {
        BlastYields.claimAllGasYields(contractAddress, feeTo);
        BlastYields.claimAllNativeYields(contractAddress, feeTo);
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// ADMIN
    //////////////////////////////////////////////////////////////////////////////////////

    function setFeeTo(address _feeTo) external onlyOwner {
        feeTo = _feeTo;
        emit LogFeeToChanged(_feeTo);
    }

    function execute(address to, uint256 value, bytes calldata data) external onlyOwner returns (bool success, bytes memory result) {
        (success, result) = to.call{value: value}(data);
    }
}
