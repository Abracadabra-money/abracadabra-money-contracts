// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "interfaces/ISolidlyPair.sol";

interface IVelodromePairFactory {
    function allPairs(uint256 index) external view returns (ISolidlyPair);

    function allPairsLength() external view returns (uint256);

    function volatileFee() external view returns (uint256);

    function stableFee() external view returns (uint256);

    function createPair(address tokenA, address tokenB, bool stable) external returns (address pair);
}
