// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {UUPSUpgradeable} from "@solady/utils/UUPSUpgradeable.sol";
import {Initializable} from "@solady/utils/Initializable.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {OwnableRoles} from "@solady/auth/OwnableRoles.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ERC4626} from "/tokens/ERC4626.sol";
import {ICauldronV4Hooks} from "/interfaces/ICauldronV4Hooks.sol";

contract MagicUSD0pp is ERC4626, OwnableRoles, UUPSUpgradeable, Initializable, ICauldronV4Hooks {
    using SafeTransferLib for address;

    // ROLES
    uint256 public constant ROLE_REWARD_OPERATOR = _ROLE_0;
    uint256 public constant ROLE_CAULDRON_EVENT_EMITTER = _ROLE_1;

    address private immutable _asset;

    constructor(address __asset) {
        _asset = __asset;
        _disableInitializers();
    }

    function initialize(address _owner) public initializer {
        _initializeOwner(_owner);
    }

    function _deposit(address by, address to, uint256 assets, uint256 shares) internal virtual override {
        super._deposit(by, to, assets, shares);
    }

    function _withdraw(address by, address to, address owner, uint256 assets, uint256 shares) internal virtual override {
        super._withdraw(by, to, owner, assets, shares);
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
    /// CAULDRON HOOKS
    ////////////////////////////////////////////////////////////////////////////////

    function onBeforeAddCollateral(
        address from,
        address to,
        uint256 share
    ) external override onlyOwnerOrRoles(ROLE_CAULDRON_EVENT_EMITTER) {}

    function onAfterAddCollateral(
        address from,
        address to,
        uint256 collateralShare
    ) external override onlyOwnerOrRoles(ROLE_CAULDRON_EVENT_EMITTER) {}

    function onBeforeBorrow(
        address from,
        address to,
        uint256 amount,
        uint256 newBorrowPart,
        uint256 part
    ) external override onlyOwnerOrRoles(ROLE_CAULDRON_EVENT_EMITTER) {}

    function onBeforeRemoveCollateral(
        address from,
        address to,
        uint256 share
    ) external override onlyOwnerOrRoles(ROLE_CAULDRON_EVENT_EMITTER) {}

    function onAfterRemoveCollateral(
        address from,
        address to,
        uint256 collateralShare
    ) external override onlyOwnerOrRoles(ROLE_CAULDRON_EVENT_EMITTER) {}

    function onBeforeUsersLiquidated(
        address from,
        address[] memory users,
        uint256[] memory maxBorrowPart
    ) external override onlyOwnerOrRoles(ROLE_CAULDRON_EVENT_EMITTER) {}

    function onBeforeUserLiquidated(
        address from,
        address user,
        uint256 borrowPart,
        uint256 borrowAmount,
        uint256 collateralShare
    ) external override onlyOwnerOrRoles(ROLE_CAULDRON_EVENT_EMITTER) {}

    function onAfterUserLiquidated(
        address from,
        address to,
        uint256 collateralShare
    ) external override onlyOwnerOrRoles(ROLE_CAULDRON_EVENT_EMITTER) {}

    ////////////////////////////////////////////////////////////////////////////////
    // REWARDS OPERATORS
    ////////////////////////////////////////////////////////////////////////////////

    function harvest(address harvester) external onlyOwnerOrRoles(ROLE_REWARD_OPERATOR) {}

    function distributeRewards(uint256 amount) external onlyOwnerOrRoles(ROLE_REWARD_OPERATOR) {}

    ////////////////////////////////////////////////////////////////////////////////
    // INTERNALS
    ////////////////////////////////////////////////////////////////////////////////

    function _authorizeUpgrade(address /*newImplementation*/) internal virtual override {
        _checkOwner();
    }
}
