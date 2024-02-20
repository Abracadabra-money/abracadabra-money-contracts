// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {OperatableV2} from "mixins/OperatableV2.sol";
import {IMintableBurnable} from "interfaces/IMintableBurnable.sol";

/// @title MintableBurnableERC20
/// @notice MintableBurnableERC20 is an ERC20 token with mint, burn functions.
/// In this context, operators are allowed minters and burners.
contract MintableBurnableERC20 is ERC20, OperatableV2, IMintableBurnable {
    constructor(
        address _owner,
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) ERC20(name_, symbol_, decimals_) OperatableV2(_owner) {}

    function burn(address from, uint256 amount) external onlyOperators returns (bool) {
        _burn(from, amount);
        return true;
    }

    function mint(address to, uint256 amount) external onlyOperators returns (bool) {
        _mint(to, amount);
        return true;
    }
}