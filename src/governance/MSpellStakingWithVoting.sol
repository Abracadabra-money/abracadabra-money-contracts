// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Ownable} from "@solady/auth/Ownable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {ERC20VotesUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import {NoncesUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {LzApp} from "@abracadabra-oftv2/LzApp.sol";
import {MSpellStakingBase} from "/staking/MSpellStaking.sol";

library MessageType {
    uint8 internal constant Deposit = 0;
    uint8 internal constant Withdraw = 1;
}

contract MSpellStakingHub is
    Initializable,
    MSpellStakingBase,
    ERC20Upgradeable,
    ERC20PermitUpgradeable,
    ERC20VotesUpgradeable,
    Ownable,
    LzApp
{
    error ErrUnsupportedOperation();

    constructor(address _mim, address _spell, address _lzEndpoint) MSpellStakingBase(_mim, _spell) LzApp(_lzEndpoint) {
        _disableInitializers();
    }

    function initialize(address _owner) public initializer {
        __ERC20_init("SpellPower", "SpellPower");
        __ERC20Permit_init("SpellPower");
        _initializeOwner(_owner);
        _setLockupEnabled(true);
    }

    function transfer(address, uint256) public virtual override returns (bool) {
        revert ErrUnsupportedOperation();
    }

    function transferFrom(address, address, uint256) public virtual override returns (bool) {
        revert ErrUnsupportedOperation();
    }

    function approve(address, uint256) public virtual override returns (bool) {
        revert ErrUnsupportedOperation();
    }

    function permit(address, address, uint256, uint256, uint8, bytes32, bytes32) public pure override {
        revert ErrUnsupportedOperation();
    }

    function nonces(address owner) public view virtual override(ERC20PermitUpgradeable, NoncesUpgradeable) returns (uint256) {
        return super.nonces(owner);
    }

    ////////////////////////////////////////////////////////////////////
    /// Views
    ////////////////////////////////////////////////////////////////////

    function initializedVersion() public view returns (uint64) {
        return _getInitializedVersion();
    }

    ////////////////////////////////////////////////////////////////////
    /// Admin
    ////////////////////////////////////////////////////////////////////

    function setToggleLockUp(bool status) external onlyOwner {
        _setLockupEnabled(status);
    }

    function setRewardHandler(address _rewardHandler) external onlyOwner {
        _setRewardHandler(_rewardHandler);
    }

    ////////////////////////////////////////////////////////////////////
    /// Internals
    ////////////////////////////////////////////////////////////////////

    function _lzAppOwner() internal view override returns (address) {
        return owner();
    }

    function _afterDeposit(address _user, uint256 _amount, uint256 /*_value*/) internal override {
        _mint(_user, _amount);
    }

    function _afterWithdraw(address _user, uint256 _amount, uint256 /*_value*/) internal override {
        _burn(_user, _amount);
    }

    function _update(address from, address to, uint256 amount) internal override(ERC20Upgradeable, ERC20VotesUpgradeable) {
        super._update(from, to, amount);
    }

    // Receive spoke chain deposit and withdraw requests
    function _blockingLzReceive(uint16 /* _srcChainId */, bytes memory, uint64, bytes memory _payload) internal override {
        (uint8 messageType, address user, uint256 amount) = abi.decode(_payload, (uint8, address, uint256));
        if (messageType == MessageType.Deposit) {
            _afterDeposit(user, amount, 0);
        } else if (messageType == MessageType.Withdraw) {
            _afterWithdraw(user, amount, 0);
        }
    }
}

contract MSpellStakingSpoke is Initializable, MSpellStakingBase, Ownable, LzApp {
    event LogSendUpdate(uint8 messageType, address user, uint256 amount);

    uint16 public constant MESSAGE_VERSION = 1;

    // assume the hub address is the same as this contract address
    bytes32 public immutable hubRecipient = bytes32(uint256(uint160(address(this))));
    uint16 public immutable lzHubChainId;

    constructor(
        address _mim,
        address _spell,
        address _lzEndpoint,
        uint16 _lzHubChainId
    ) MSpellStakingBase(_mim, _spell) LzApp(_lzEndpoint) {
        lzHubChainId = _lzHubChainId;
        _disableInitializers();
    }

    function initialize(address _owner) public initializer {
        _initializeOwner(_owner);
        _setLockupEnabled(true);
    }

    ////////////////////////////////////////////////////////////////////
    /// Views
    ////////////////////////////////////////////////////////////////////

    function initializedVersion() public view returns (uint64) {
        return _getInitializedVersion();
    }

    ////////////////////////////////////////////////////////////////////
    /// Admin
    ////////////////////////////////////////////////////////////////////

    function setToggleLockUp(bool status) external onlyOwner {
        _setLockupEnabled(status);
    }

    function setRewardHandler(address _rewardHandler) external onlyOwner {
        _setRewardHandler(_rewardHandler);
    }

    ////////////////////////////////////////////////////////////////////
    /// Views
    ////////////////////////////////////////////////////////////////////

    function _lzAppOwner() internal view override returns (address) {
        return owner();
    }

    /// @dev message format:
    /// - messageType: uint8
    /// - user: address
    /// - amount: uint256
    function estimateBridgingFee() external view returns (uint256 fee) {
        // exact information not required for estimation
        bytes memory payload = abi.encodePacked(uint8(0), bytes32(0), uint256(1));
        (fee, ) = lzEndpoint.estimateFees(lzHubChainId, address(this), payload, false, "");
    }

    //////////////////////////////////////////////////////////////////////
    /// Internals
    //////////////////////////////////////////////////////////////////////

    function _afterDeposit(address _user, uint256 _amount, uint256 _value) internal override {
        _sendUpdate(MessageType.Deposit, _user, _amount, _value);
    }

    function _afterWithdraw(address _user, uint256 _amount, uint256 _value) internal override {
        _sendUpdate(MessageType.Withdraw, _user, _amount, _value);
    }

    function _sendUpdate(uint8 _messageType, address _user, uint256 _amount, uint256 _value) internal {
        bytes memory _adapterParams = abi.encodePacked(MESSAGE_VERSION, uint256(minDstGasLookup[lzHubChainId][MESSAGE_VERSION]));

        _lzSend(
            lzHubChainId,
            abi.encode(_messageType, _user, _amount), // payload
            payable(_user), // refund address
            address(0), // unused
            _adapterParams,
            _value
        );

        emit LogSendUpdate(_messageType, _user, _amount);
    }

    function _blockingLzReceive(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64 _nonce,
        bytes memory _payload
    ) internal virtual override {}
}
