// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {OperatableV2} from "mixins/OperatableV2.sol";
import {Pausable} from "openzeppelin-contracts/security/Pausable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {MathLib} from "libraries/MathLib.sol";
import {MultiRewardsStaking} from "periphery/MultiRewardsStaking.sol";

/// @notice Permissioned version of MultiRewardsStaking
contract PrivateMultiRewardsStaking is MultiRewardsStaking {
    event LogAuthorizedChanged(address indexed, bool);
    error ErrNotAuthorized();

    mapping(address => bool) public authorized;

    modifier onlyAuthorized() {
        if (!authorized[msg.sender]) {
            revert ErrNotAuthorized();
        }
        _;
    }

    constructor(address _stakingToken, address _owner) MultiRewardsStaking(_stakingToken, _owner) {}

    function stake(uint256 amount) public override onlyAuthorized {
        super.stake(amount);
    }

    function withdraw(uint256 amount) public override onlyAuthorized {
        super.withdraw(amount);
    }

    function getRewards() public override onlyAuthorized {
        super.getRewards();
    }

    function exit() public override onlyAuthorized {
        super.exit();
    }

    //////////////////////////////////////////////////////////////////////////////////////////////
    /// ADMIN
    //////////////////////////////////////////////////////////////////////////////////////////////
    function setAuthorized(address account, bool status) external onlyOwner {
        authorized[account] = status;
        emit LogAuthorizedChanged(account, status);
    }
}
