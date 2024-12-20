// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {UUPSUpgradeable} from "@solady/utils/UUPSUpgradeable.sol";
import {Initializable} from "@solady/utils/Initializable.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {OwnableOperators} from "/mixins/OwnableOperators.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ERC4626} from "/tokens/ERC4626.sol";

contract MagicUSD0pp is ERC4626, OwnableOperators, UUPSUpgradeable, Initializable {
    address constant USUAL_TOKEN = 0xC4441c2BE5d8fA8126822B9929CA0b81Ea0DE38E;

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
    // VIEWS
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
    // REWARDS OPERATORS
    ////////////////////////////////////////////////////////////////////////////////

    function harvest(address harvester) external onlyOperators {
        USUAL_TOKEN.safeTransfer(harvester, USUAL_TOKEN.balanceOf(address(this)));
    }

    function distributeRewards(uint256 amount) external onlyOperators {
        _asset.safeTransferFrom(msg.sender, address(this), amount);
        unchecked {
            _totalAssets += amount;
        }
    }

    ////////////////////////////////////////////////////////////////////////////////
    // INTERNALS
    ////////////////////////////////////////////////////////////////////////////////

    function _authorizeUpgrade(address /*newImplementation*/) internal virtual override {
        _checkOwner();
    }
}
