// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {UUPSUpgradeable} from "@solady/utils/UUPSUpgradeable.sol";
import {Initializable} from "@solady/utils/Initializable.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {OwnableOperators} from "/mixins/OwnableOperators.sol";
import {ERC4626} from "/tokens/ERC4626.sol";
import {IInfraredStaking} from "/interfaces/IInfraredStaking.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

contract MagicInfraredVault is ERC4626, OwnableOperators, UUPSUpgradeable, Initializable {
    using SafeTransferLib for address;

    event LogStakingChanged(address staking);
    event LogTokenRescue(address token, address to, uint256 amount);

    error ErrNotAllowed();

    address private immutable _asset;
    IInfraredStaking public staking;

    constructor(address asset_) {
        _asset = asset_;
        _disableInitializers();
    }

    function initialize(address _owner) public initializer {
        _initializeOwner(_owner);
    }

    ////////////////////////////////////////////////////////////////////////////////
    // Views
    ////////////////////////////////////////////////////////////////////////////////

    function name() public view virtual override returns (string memory) {
        return string(abi.encodePacked("Magic-", IERC20Metadata(_asset).name()));
    }

    function symbol() public view virtual override returns (string memory) {
        return string(abi.encodePacked("Magic-", IERC20Metadata(_asset).symbol()));
    }

    function asset() public view virtual override returns (address) {
        return _asset;
    }

    ////////////////////////////////////////////////////////////////////////////////
    // Operators
    ////////////////////////////////////////////////////////////////////////////////

    function harvest(address harvester) external onlyOperators {
        staking.getReward();

        address[] memory rewards = staking.getAllRewardTokens();
        for (uint256 i = 0; i < rewards.length; i++) {
            uint balance = rewards[i].balanceOf(address(this));
            if (balance > 0) {
                rewards[i].safeTransfer(harvester, balance);
            }
        }
    }

    function distributeRewards(uint256 amount) external onlyOperators {
        _asset.safeTransferFrom(msg.sender, address(this), amount);
        staking.stake(amount);

        unchecked {
            _totalAssets += amount;
        }
    }

    ////////////////////////////////////////////////////////////////////////////////
    // Admin
    ////////////////////////////////////////////////////////////////////////////////

    function setStaking(IInfraredStaking _staking) external onlyOwner {
        if (address(staking) != address(0)) {
            _asset.safeApprove(address(staking), 0);
        }

        _asset.safeApprove(address(_staking), type(uint256).max);

        staking = _staking;
        emit LogStakingChanged(address(_staking));
    }

    function rescue(address token, address to, uint256 amount) external onlyOwner {
        require(token != asset(), ErrNotAllowed());

        token.safeTransfer(to, amount);
        emit LogTokenRescue(token, to, amount);
    }

    ////////////////////////////////////////////////////////////////////////////////
    // Internals
    ////////////////////////////////////////////////////////////////////////////////

    function _afterDeposit(uint256 assets, uint256 /* shares */) internal override {
        staking.stake(assets);
    }

    function _beforeWithdraw(uint256 assets, uint256 /* shares */) internal override {
        staking.withdraw(assets);
    }

    function _authorizeUpgrade(address /*newImplementation*/) internal virtual override {
        _checkOwner();
    }
}
