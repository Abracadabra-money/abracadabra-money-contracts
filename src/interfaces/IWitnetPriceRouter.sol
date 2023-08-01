// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface IWitnetPriceRouter {
     /// Returns the ERC-165-compliant price feed contract currently serving 
    /// updates on the given currency pair.
    function valueFor(bytes32 _erc2362id) external view returns (int256,uint256,uint256);
}