// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {UUPSUpgradeable} from "@solady/utils/UUPSUpgradeable.sol";
import {Initializable} from "@solady/utils/Initializable.sol";
import {OwnableRoles} from "@solady/auth/OwnableRoles.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {ERC4626} from "/tokens/ERC4626.sol";
import {IKodiakVaultV1, IKodiakVaultStaking} from "/interfaces/IKodiak.sol";

contract MagicKodiakVault is ERC4626, OwnableRoles, UUPSUpgradeable, Initializable {
    using SafeTransferLib for address;

    event LogStakingChanged(address staking);

    uint256 public constant ROLE_OPERATOR = _ROLE_0;
    uint256 public constant ZERO_LOCKTIME = 0;

    address private immutable _asset;

    IKodiakVaultStaking public staking;

    constructor(address __asset) {
        _asset = __asset;
    }

    function initialize(address _owner, address _staking) public initializer {
        _initializeOwner(_owner);

        _asset.safeApprove(address(_staking), type(uint256).max);
        staking = IKodiakVaultStaking(_staking);
    }

    ////////////////////////////////////////////////////////////////////////////////
    // Views
    ////////////////////////////////////////////////////////////////////////////////

    function name() public view virtual override returns (string memory) {
        return string(abi.encodePacked("Magic", IKodiakVaultV1(_asset).name()));
    }

    function symbol() public view virtual override returns (string memory) {
        return "MagicKodiak Vault";
    }

    function asset() public view virtual override returns (address) {
        return _asset;
    }

    ////////////////////////////////////////////////////////////////////////////////
    // Operators
    ////////////////////////////////////////////////////////////////////////////////

    function harvest(address harvester) external onlyOwnerOrRoles(ROLE_OPERATOR) {
        staking.getReward();

        address[] memory rewards = staking.getAllRewardTokens();
        for (uint256 i = 0; i < rewards.length; i++) {
            rewards[i].safeTransfer(harvester, rewards[i].balanceOf(address(this)));
        }
    }

    function distributeRewards(uint256 amount) external onlyOwnerOrRoles(ROLE_OPERATOR) {
        _asset.safeTransferFrom(msg.sender, address(this), amount);
        staking.withdrawLockedAll();
        staking.stakeLocked(amount, ZERO_LOCKTIME);

        unchecked {
            _totalAssets += amount;
        }
    }

    ////////////////////////////////////////////////////////////////////////////////
    // Admin
    ////////////////////////////////////////////////////////////////////////////////

    function setStaking(IKodiakVaultStaking _staking) external onlyOwner {
        if (address(staking) != address(0)) {
            _asset.safeApprove(address(staking), 0);
        }

        _asset.safeApprove(address(_staking), type(uint256).max);

        staking = _staking;
        emit LogStakingChanged(address(_staking));
    }

    ////////////////////////////////////////////////////////////////////////////////
    // Internals
    ////////////////////////////////////////////////////////////////////////////////

    function _afterDeposit(uint256 assets, uint256 /* shares */) internal override {
        staking.withdrawLockedAll();
        staking.stakeLocked(assets, ZERO_LOCKTIME);
    }

    function _beforeWithdraw(uint256 assets, uint256 /* shares */) internal override {
        staking.withdrawLockedAll();
        uint amount = _asset.balanceOf(address(this)) - assets;
        staking.stakeLocked(amount, ZERO_LOCKTIME);
    }

    function _authorizeUpgrade(address /*newImplementation*/) internal virtual override {
        _checkOwner();
    }
}
