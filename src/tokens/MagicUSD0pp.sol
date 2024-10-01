// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {UUPSUpgradeable} from "@solady/utils/UUPSUpgradeable.sol";
import {Initializable} from "@solady/utils/Initializable.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {OwnableOperators} from "/mixins/OwnableOperators.sol";
import {ERC4626} from "/tokens/ERC4626.sol";

contract MagicUSD0pp is ERC4626, OwnableOperators, UUPSUpgradeable, Initializable {
    using SafeTransferLib for address;

    address private immutable _asset;

    constructor(address __asset) {
        _asset = __asset;
        _disableInitializers();
    }

    function initialize(address _owner) public initializer {
        _initializeOwner(_owner);
    }

    ////////////////////////////////////////////////////////////////////////////////
    // Views
    ////////////////////////////////////////////////////////////////////////////////

    function name() public view virtual override returns (string memory) {
        return "MagicUSD0++";
    }

    function symbol() public view virtual override returns (string memory) {
        return "MagicUSD0++";
    }

    function asset() public view virtual override returns (address) {
        return _asset;
    }

    ////////////////////////////////////////////////////////////////////////////////
    // Operators
    ////////////////////////////////////////////////////////////////////////////////

    function harvest(address harvester) external onlyOperators {
        // TODO: harvest rewards
    }

    function distributeRewards(uint256 amount) external onlyOperators {
        _asset.safeTransferFrom(msg.sender, address(this), amount);

        // TODO: deposit reward assets

        unchecked {
            _totalAssets += amount;
        }
    }

    ////////////////////////////////////////////////////////////////////////////////
    // Internals
    ////////////////////////////////////////////////////////////////////////////////

    function _afterDeposit(uint256 assets, uint256 /* shares */) internal override {}

    function _beforeWithdraw(uint256 assets, uint256 /* shares */) internal override {}

    function _authorizeUpgrade(address /*newImplementation*/) internal virtual override {
        _checkOwner();
    }
}
