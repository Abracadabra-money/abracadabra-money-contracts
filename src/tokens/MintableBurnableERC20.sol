// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "solmate/tokens/ERC20.sol";
import "mixins/OperatableV2.sol";
import "interfaces/IMintableBurnable.sol";

contract MintableBurnableERC20 is ERC20, OperatableV2, IMintableBurnable {
    constructor(
        address _defaultOperator,
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) ERC20(name_, symbol_, decimals_) OperatableV2(_defaultOperator) {}

    function burn(address from, uint256 amount) external onlyOperators returns (bool) {
        _burn(from, amount);
        return true;
    }

    function mint(address to, uint256 amount) external onlyOperators returns (bool) {
        _mint(to, amount);
        return true;
    }
}
