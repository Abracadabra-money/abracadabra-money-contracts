// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ERC20} from "@solady/tokens/ERC20.sol";
import {OwnableOperators} from "/mixins/OwnableOperators.sol";
import {IMintableBurnable} from "/interfaces/IMintableBurnable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@solady/utils/UUPSUpgradeable.sol";

contract MintableBurnableUpgradeableERC20 is ERC20, OwnableOperators, UUPSUpgradeable, IMintableBurnable, Initializable {
    string public _name;
    string private _symbol;
    uint8 private _decimals;

    constructor() {
        _disableInitializers();
    }

    function initialize(string memory name_, string memory symbol_, uint8 decimals_, address owner_) external initializer {
        _initializeOwner(owner_);
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// VIEWS
    //////////////////////////////////////////////////////////////////////////////////////

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// OPERATORS
    //////////////////////////////////////////////////////////////////////////////////////

    function burn(address from, uint256 amount) external onlyOperators returns (bool) {
        _burn(from, amount);
        return true;
    }

    function mint(address to, uint256 amount) external onlyOperators returns (bool) {
        _mint(to, amount);
        return true;
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// INTERNALS
    //////////////////////////////////////////////////////////////////////////////////////

    function _authorizeUpgrade(address /*newImplementation*/) internal virtual override {
        _checkOwner();
    }
}
