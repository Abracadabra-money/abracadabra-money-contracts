// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface IPriceProvider {
    function getPrice(address token) external view returns (int256);
}
