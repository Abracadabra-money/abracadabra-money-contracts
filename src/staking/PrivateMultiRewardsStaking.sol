// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {UUPSUpgradeable} from "@solady/utils/UUPSUpgradeable.sol";
import {Initializable} from "@solady/utils/Initializable.sol";
import {MathLib} from "/libraries/MathLib.sol";
import {MultiRewards, RewardHandlerParams} from "/staking/MultiRewards.sol";

/// @notice Permissioned version of MultiRewards
contract PrivateMultiRewardsStaking is MultiRewards {
    constructor(address _stakingToken, address _owner) MultiRewards(_stakingToken, _owner) {}

    function stake(uint256 amount) public override onlyOwnerOrRoles(ROLE_OPERATOR) {
        super.stake(amount);
    }

    function withdraw(uint256 amount) public override onlyOwnerOrRoles(ROLE_OPERATOR) {
        super.withdraw(amount);
    }

    function getRewards() public override onlyOwnerOrRoles(ROLE_OPERATOR) {
        super.getRewards();
    }

    function exit() public override onlyOwnerOrRoles(ROLE_OPERATOR) {
        super.exit();
    }
}

contract UpgradeablePrivateMultiRewards is MultiRewards, UUPSUpgradeable, Initializable {
    error ErrNotAvailable();

    constructor(address _stakingToken, address _owner) MultiRewards(_stakingToken, _owner) {
        _disableInitializers();
    }

    function initialize(address _owner) external initializer {
        _initializeOwner(_owner);
    }

    function stake(uint256 amount) public virtual override onlyOwnerOrRoles(ROLE_OPERATOR) {
        super.stake(amount);
    }

    function withdraw(uint256 amount) public virtual override onlyOwnerOrRoles(ROLE_OPERATOR) {
        super.withdraw(amount);
    }

    function exit() public virtual override onlyOwnerOrRoles(ROLE_OPERATOR) {
        super.exit();
    }

    function exit(RewardHandlerParams memory params) public payable virtual override onlyOwnerOrRoles(ROLE_OPERATOR) {
        super.exit(params);
    }

    function _authorizeUpgrade(address /*newImplementation*/) internal virtual override {
        _checkOwner();
    }
}
