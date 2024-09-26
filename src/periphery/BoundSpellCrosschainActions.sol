// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {ILzOFTV2, ILzApp, ILzBaseOFTV2, ILzCommonOFT, ILzOFTReceiverV2} from "@abracadabra-oftv2/interfaces/ILayerZero.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {Ownable} from "@solady/auth/Ownable.sol";
import {OwnableOperators} from "/mixins/OwnableOperators.sol";
import {SpellPowerStaking} from "/staking/SpellPowerStaking.sol";
import {RewardHandlerParams} from "/staking/MultiRewards.sol";
import {TokenLocker} from "/periphery/TokenLocker.sol";
import {FeeCollectable} from "/mixins/FeeCollectable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/// @notice DRAFT IMPLEMENTATION
/// BoundSpellRemoteCalls is used on any chains except Arbitrum (Hub/Receiver) to initiate crosschain actions
/// - [MINT_BOUNDSPELL] Bridge SPELL to BoundSpellRemoteReceiver and mint BoundSPELL
/// - [REDEEM_BOUNDSPELL] Initiate redemption of BoundSPELL on Arbitrum
/// - [CLAIM_SPELL] Claim SPELL from BoundSpellRemoteReceiver once available on TockerLocker (Arbitrum)
/// - [INSTANT_REDEEM_BOUNDSPELL] Instant redeem BoundSPELL instantly on Arbitrum and bridge back to SPELL

enum CrosschainActions {
    MINT_BOUNDSPELL,
    REDEEM_BOUNDSPELL,
    CLAIM_SPELL,
    INSTANT_REDEEM_BOUNDSPELL,
    STAKE_BOUNDSPELL,
    MINT_AND_STAKE_BOUNDSPELL,
    UNSTAKE_BOUNDSPELL_AND_REDEEM,
    UNSTAKE_BOUNDSPELL_AND_INSTANT_REDEEM
}

contract BoundSpellActionSender is OwnableOperators, Pausable {
    uint16 public constant LZ_HUB_CHAIN_ID = 110; // Arbitrum

    ILzOFTV2 public immutable spellOft;
    ILzOFTV2 public immutable bSpellOft;

    constructor(ILzOFTV2 _spellOft, ILzOFTV2 _bSpellOft, address _owner) OwnableOperators() {
        spellOft = _spellOft;
        bSpellOft = _bSpellOft;
        _initializeOwner(_owner);
    }

    function send(CrosschainActions _action, uint256 /*_amount*/, bytes memory /*_adapterParams*/) external view whenNotPaused {
        if (_action == CrosschainActions.MINT_BOUNDSPELL) {
            //_sendMintBoundSpell(_amount, msg.sender, _adapterParams);
        } else if (_action == CrosschainActions.REDEEM_BOUNDSPELL) {
            //_sendRedeemBoundSpell();
        } else if (_action == CrosschainActions.CLAIM_SPELL) {
            //_sendClaimSpell();
        } else if (_action == CrosschainActions.INSTANT_REDEEM_BOUNDSPELL) {
            //_sendInstantRedeemBoundSpell();
        } else {
            revert("BoundSpellRemoteSender: Invalid action");
        }
    }

    //////////////////////////////////////////////////////////////////////////////////////////////
    /// ADMIN
    //////////////////////////////////////////////////////////////////////////////////////////////

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    //////////////////////////////////////////////////////////////////////////////////
    // INTERNALS
    //////////////////////////////////////////////////////////////////////////////////

    /*function _sendMintBoundSpell(uint256 _amount, address _user, bytes memory _adapterParams) internal {
        // Encode the payload
        bytes memory payload = abi.encode(
            CrosschainActions.MINT_BOUNDSPELL,
            _user,
            RewardHandlerParams(0, 0, 0, 0) // Placeholder values, replace with actual values if needed
        );

        // Send the message
        spellOft.sendAndCall(
            address(this), // From address
            LZ_HUB_CHAIN_ID, // Destination chain ID
            bytes32(uint256(uint160(address(this)))), // Destination address (same as this contract)
            _amount,
            payload,
            , // No extra gas needed for the call
            ILzCommonOFT.LzCallParams(
                payable(address(msg.sender)), // Refund address
                address(0), // ZRO payment address (not used)
                _adapterParams
            )
        );
    }*/
}

contract BoundSpellActionReceiver is ILzOFTReceiverV2, Ownable, FeeCollectable {
    using SafeTransferLib for address;

    event LogRescued(address token, uint256 amount, address to);

    error ErrInvalidSender();
    error ErrInvalidSourceChainId();

    uint16 internal constant LzArbitrumChainId = 110;

    address public immutable spellV2;
    ILzOFTV2 public immutable spellOft;
    ILzOFTV2 public immutable bSpellOft;
    SpellPowerStaking public immutable spellPowerStaking;
    TokenLocker public immutable boundSpellLocker;

    /// @dev Assumes the remote address is the same address as this contract
    /// must be deployed with CREATE3
    bytes32 public immutable remoteSender = bytes32(uint256(uint160(address(this))));

    constructor(ILzOFTV2 _spellOft, ILzOFTV2 _bSpellOft, SpellPowerStaking _spellPowerStaking, TokenLocker _boundSpellLocker) {
        spellOft = _spellOft;
        bSpellOft = _bSpellOft;
        spellPowerStaking = _spellPowerStaking;
        boundSpellLocker = _boundSpellLocker;
        spellV2 = ILzBaseOFTV2(address(_spellOft)).innerToken();
    }

    function onOFTReceived(
        uint16 _srcChainId, // Any chains except Arbitrum
        bytes calldata, // [ignored] _srcAddress: Remote OFT, using msg.sender against local oft to validate instead
        uint64, // [ignored] _nonce
        bytes32 _from, // BoundSpellActionSender
        uint256 _amount,
        bytes calldata _payload // (CrosschainActions action, address user, RewardHandlerParams rewardHandlerParams)
    ) external override {
        if (_srcChainId != LzArbitrumChainId) {
            revert ErrInvalidSourceChainId();
        }
        if (_from != remoteSender) {
            revert ErrInvalidSender();
        }

        if (msg.sender == address(spellOft)) {
            _handleSpellActions(_amount, _payload);
        } else if (msg.sender == address(bSpellOft)) {
            //_handleBoundSpellActions(_amount, _payload);
        } else {
            revert ErrInvalidSender();
        }
    }

    //////////////////////////////////////////////////////////////////////////////////////////////
    /// ADMIN
    //////////////////////////////////////////////////////////////////////////////////////////////

    function rescue(address token, uint256 amount, address to) external onlyOwner {
        token.safeTransfer(to, amount);
        emit LogRescued(token, amount, to);
    }

    //////////////////////////////////////////////////////////////////////////////////
    // INTERNALS
    //////////////////////////////////////////////////////////////////////////////////

    function _handleSpellActions(uint256 _amount, bytes calldata _payload) internal {
        (CrosschainActions action, address user /*RewardHandlerParams memory rewardHandlerParams*/, ) = abi.decode(
            _payload,
            (CrosschainActions, address, RewardHandlerParams)
        );

        if (action == CrosschainActions.MINT_BOUNDSPELL) {
            spellV2.safeApprove(address(boundSpellLocker), _amount);
            boundSpellLocker.mint(_amount, user);
        } else if (action == CrosschainActions.REDEEM_BOUNDSPELL) {
            address to = user; // or crosschain redeemer / this contract?
            boundSpellLocker.redeemFor(user, _amount, to, type(uint256).max);
        } else if (action == CrosschainActions.CLAIM_SPELL) {
            address to = user; // or crosschain redeemer / this contract?
            boundSpellLocker.claimFor(user, to);
        } else if (action == CrosschainActions.INSTANT_REDEEM_BOUNDSPELL) {
            address to = user; // or crosschain redeemer / this contract?
            boundSpellLocker.instantRedeemFor(user, _amount, to);
        } else {
            revert("BoundSpellRemoteReceiver: Invalid action");
        }
    }

    function _isFeeOperator(address account) internal virtual override returns (bool) {
        return owner() == account;
    }
}
