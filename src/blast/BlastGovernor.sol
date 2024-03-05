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

    function claimNativeYields(address contractAddress) external onlyOperators returns (uint256) {
        return BlastYields.claimAllNativeYields(contractAddress, feeTo);
    }

    function claimMaxGasYields(address contractAddress) external onlyOperators returns (uint256) {
        return BlastYields.claimMaxGasYields(contractAddress, feeTo);
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// ADMIN
    //////////////////////////////////////////////////////////////////////////////////////

    function setFeeTo(address _feeTo) external onlyOwner {
        if(_feeTo == address(0)) {
            revert ErrZeroAddress();
        }
        
        feeTo = _feeTo;
        emit LogFeeToChanged(_feeTo);
    }

    function callBlastPrecompile(bytes calldata data) external onlyOwner {
        BlastYields.callPrecompile(data);
    }

    function execute(address to, uint256 value, bytes calldata data) external onlyOwner returns (bool success, bytes memory result) {
        (success, result) = to.call{value: value}(data);
    }
}
