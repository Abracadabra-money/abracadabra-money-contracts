// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {ILzOFTV2, ILzApp, ILzBaseOFTV2, ILzCommonOFT, ILzOFTReceiverV2} from "@abracadabra-oftv2/interfaces/ILayerZero.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {Ownable} from "@solady/auth/Ownable.sol";
import {SpellPowerStaking} from "/staking/SpellPowerStaking.sol";
import {RewardHandlerParams} from "/staking/MultiRewards.sol";
import {TokenLocker} from "/periphery/TokenLocker.sol";
import {FeeCollectable} from "/mixins/FeeCollectable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/// @notice DRAFT IMPLEMENTATION
/// BoundSpellRemoteCalls is used on any chains except Arbitrum (Hub/Receiver) to initiate crosschain actions

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

struct Payload {
    CrosschainActions action;
    bytes data;
}

struct MintBoundSpellParams {
    address user;
    RewardHandlerParams rewardHandlerParams;
}

uint16 constant LZ_HUB_CHAIN_ID = 110; // Arbitrum
uint8 constant PT_SEND = 0;
uint8 constant PT_SEND_AND_CALL = 1;
uint8 constant MESSAGE_VERSION = 1;

contract BoundSpellActionSender is Ownable, Pausable {
    using SafeTransferLib for address;

    event LogRescued(address token, uint256 amount, address to);

    error ErrInvalidAction();

    address public immutable spellV2;
    ILzOFTV2 public immutable spellOft;
    ILzOFTV2 public immutable bSpellOft;

    mapping(CrosschainActions => uint64) public gasPerAction;

    constructor(ILzOFTV2 _spellOft, ILzOFTV2 _bSpellOft, address _owner) {
        spellOft = _spellOft;
        bSpellOft = _bSpellOft;
        spellV2 = ILzBaseOFTV2(address(_spellOft)).innerToken();
        _initializeOwner(_owner);
    }

    //////////////////////////////////////////////////////////////////////////////////////////////
    /// VIEWS
    //////////////////////////////////////////////////////////////////////////////////////////////

    function estimate(CrosschainActions _action) external view returns (uint256 /*fee*/, uint256 /*unused*/) {
        uint64 dstGasForCall = gasPerAction[_action];
        ILzOFTV2 oft;
        bytes memory payload;

        if (_action == CrosschainActions.MINT_BOUNDSPELL) {
            oft = spellOft;
            payload = abi.encode(_action, msg.sender);
        } else if (_action == CrosschainActions.REDEEM_BOUNDSPELL) {
            // TODO: Implement
        } else if (_action == CrosschainActions.CLAIM_SPELL) {
            // TODO: Implement
        } else if (_action == CrosschainActions.INSTANT_REDEEM_BOUNDSPELL) {
            // TODO: Implement
        } else {
            revert ErrInvalidAction();
        }

        uint256 minGas = ILzApp(address(oft)).minDstGasLookup(LZ_HUB_CHAIN_ID, 1);

        return
            oft.estimateSendAndCallFee(
                LZ_HUB_CHAIN_ID,
                bytes32(uint256(uint160(address(this)))), // Destination address (same as this contract)
                1, // amount - no need to estimate
                payload,
                dstGasForCall,
                false,
                abi.encodePacked(uint16(1), minGas + dstGasForCall) // must include minGas + dstGasForCall
            );
    }

    //////////////////////////////////////////////////////////////////////////////////////////////
    /// PERMISSIONLESS
    //////////////////////////////////////////////////////////////////////////////////////////////

    function send(CrosschainActions _action, uint256 _amount) external whenNotPaused {
        uint64 dstGasForCall = gasPerAction[_action];

        if (_action == CrosschainActions.MINT_BOUNDSPELL) {
            _sendMintBoundSpell(_amount, msg.sender, dstGasForCall);
        } else if (_action == CrosschainActions.REDEEM_BOUNDSPELL) {
            // TODO: Implement
        } else if (_action == CrosschainActions.CLAIM_SPELL) {
            // TODO: Implement
        } else if (_action == CrosschainActions.INSTANT_REDEEM_BOUNDSPELL) {
            // TODO: Implement
        } else {
            revert ErrInvalidAction();
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

    function rescue(address token, uint256 amount, address to) external onlyOwner {
        token.safeTransfer(to, amount);
        emit LogRescued(token, amount, to);
    }

    //////////////////////////////////////////////////////////////////////////////////
    // INTERNALS
    //////////////////////////////////////////////////////////////////////////////////

    function _sendMintBoundSpell(uint256 _amount, address _user, uint64 dstGasForCall) internal {
        bytes memory params = abi.encode(MintBoundSpellParams(_user, RewardHandlerParams("", 0)));
        bytes memory payload = abi.encode(Payload(CrosschainActions.MINT_BOUNDSPELL, params));

        uint256 minGas = ILzApp(address(spellOft)).minDstGasLookup(LZ_HUB_CHAIN_ID, MESSAGE_VERSION);

        spellV2.safeTransferFrom(msg.sender, address(this), _amount);

        spellOft.sendAndCall{value: msg.value}(
            address(this),
            LZ_HUB_CHAIN_ID,
            bytes32(uint256(uint160(address(this)))),
            _amount,
            payload,
            dstGasForCall,
            ILzCommonOFT.LzCallParams(payable(address(msg.sender)), address(0), abi.encodePacked(uint16(1), minGas + dstGasForCall))
        );
    }
}

/// @dev Some actions would need to take a fee to cover bridging back to the source chain fees
contract BoundSpellActionReceiver is ILzOFTReceiverV2, Ownable, FeeCollectable {
    using SafeTransferLib for address;

    event LogRescued(address token, uint256 amount, address to);
    event LogMintBoundSpell(address user, uint256 amount);

    error ErrInvalidSender();
    error ErrInvalidSourceChainId();
    error ErrInvalidAction();

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
        if (_srcChainId != LZ_HUB_CHAIN_ID) {
            revert ErrInvalidSourceChainId();
        }
        if (_from != remoteSender) {
            revert ErrInvalidSender();
        }

        Payload memory payload = abi.decode(_payload, (Payload));

        if (payload.action == CrosschainActions.MINT_BOUNDSPELL) {
            MintBoundSpellParams memory mintBoundSpellParams = abi.decode(payload.data, (MintBoundSpellParams));
            _handleMintBoundSpell(_amount, mintBoundSpellParams);
        } else if (payload.action == CrosschainActions.INSTANT_REDEEM_BOUNDSPELL) {
            // TODO: Implement
        } else {
            revert ErrInvalidAction();
        }
    }

    //////////////////////////////////////////////////////////////////////////////////////////////
    /// ADMIN
    //////////////////////////////////////////////////////////////////////////////////////////////

    function rescue(address token, uint256 amount, address to) external onlyOwner {
        token.safeTransfer(to, amount);
        emit LogRescued(token, amount, to);
    }

    function _isFeeOperator(address account) internal virtual override returns (bool) {
        return owner() == account;
    }

    //////////////////////////////////////////////////////////////////////////////////////////////
    /// INTERNALS
    //////////////////////////////////////////////////////////////////////////////////////////////

    function _handleMintBoundSpell(uint256 _amount, MintBoundSpellParams memory _params) internal {
        spellV2.safeApprove(address(boundSpellLocker), _amount);
        boundSpellLocker.mint(_amount, _params.user);

        emit LogMintBoundSpell(_params.user, _amount);
    }
}
