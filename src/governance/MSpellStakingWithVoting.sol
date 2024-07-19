// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {MSpellStakingBase} from "/staking/MSpellStaking.sol";
import {LzNonblockingApp} from "/mixins/LzNonblockingApp.sol";

library MessageType {
    uint8 internal constant Deposit = 0;
    uint8 internal constant Withdraw = 1;
}

contract MSpellStakingHub is MSpellStakingBase, ERC20, ERC20Permit, ERC20Votes, LzNonblockingApp {
    constructor(
        address _mim,
        address _spell,
        address _lzEndpoint,
        address _owner
    ) MSpellStakingBase(_mim, _spell) ERC20("mSPELL", "mSPELL") ERC20Permit("mSPELL") LzNonblockingApp(_lzEndpoint, _owner) {}

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

    function stakingOperator() public view override returns (address) {
        return owner;
    }

    function nonces(address owner) public view virtual override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }

    ////////////////////////////////////////////////////////////////////
    /// Internals
    ////////////////////////////////////////////////////////////////////

    function _afterDeposit(address _user, uint256 _amount) internal override {
        _mint(_user, _amount);
    }

    function _afterWithdraw(address _user, uint256 _amount) internal override {
        _burn(_user, _amount);
    }

    function _update(address from, address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._update(from, to, amount);
    }

    // Receive spoke chain deposit and withdraw requests
    function _nonblockingLzReceive(uint16 /* _srcChainId */, bytes memory, uint64, bytes memory _payload, bool) internal override {
        (uint8 messageType, address user, uint256 amount) = abi.decode(_payload, (uint8, address, uint256));
        if (messageType == MessageType.Deposit) {
            _afterDeposit(user, amount);
        } else if (messageType == MessageType.Withdraw) {
            _afterWithdraw(user, amount);
        }
    }
}

contract MSpellStakingSpoke is MSpellStakingBase, LzNonblockingApp {
    event LogSendUpdate(uint8 messageType, address user, uint256 amount);

    // assume the hub address is the same as this contract address
    bytes32 public immutable hubRecipient = bytes32(uint256(uint160(address(this))));

    uint16 public immutable lzHubChainId;

    constructor(
        address _mim,
        address _spell,
        address _lzEndpoint,
        uint16 _lzHubChainId,
        address _owner
    ) MSpellStakingBase(_mim, _spell) LzNonblockingApp(_lzEndpoint, _owner) {
        lzHubChainId = _lzHubChainId;
    }

    function stakingOperator() public view override returns (address) {
        return owner;
    }

    ////////////////////////////////////////////////////////////////////
    /// Views
    ////////////////////////////////////////////////////////////////////

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
    function _afterDeposit(address _user, uint256 _amount) internal override {
        _sendUpdate(MessageType.Deposit, _user, _amount);
    }

    function _afterWithdraw(address _user, uint256 _amount) internal override {
        _sendUpdate(MessageType.Withdraw, _user, _amount);
    }

    function _sendUpdate(uint8 messageType, address user, uint256 amount) internal {
        _lzSend(lzHubChainId, abi.encode(messageType, user, amount), payable(user), address(0), bytes(""), msg.value);

        emit LogSendUpdate(messageType, user, amount);
    }

    function _nonblockingLzReceive(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64 _nonce,
        bytes memory _payload,
        bool retry
    ) internal override {}
}
