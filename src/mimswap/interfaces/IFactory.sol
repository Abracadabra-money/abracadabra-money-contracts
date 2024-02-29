// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface IFactory {
    function create(address baseToken_, address quoteToken_, uint256 lpFeeRate_, uint256 i_, uint256 k_) external returns (address clone);
}
