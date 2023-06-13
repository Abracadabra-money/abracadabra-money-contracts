// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface ICauldronFeeWithdrawReporter {
    function payload() external view returns (bytes memory);
}
