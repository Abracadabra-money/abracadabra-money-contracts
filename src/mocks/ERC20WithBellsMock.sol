// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/mocks/MockERC20.sol";

/// @dev Velodrome pair factory requires decimals and symbol :(
contract ERC20WithBellsMock is MockERC20 {
    uint8 public decimals = 0;
    string public symbol;

    constructor(
        uint256 _initialAmount,
        uint8 _decimals,
        string memory _symbol
    ) MockERC20(_initialAmount) {
        decimals = _decimals;
        symbol = _symbol;
    }
}
