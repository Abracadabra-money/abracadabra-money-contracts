// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {ILzOFTV2, ILzApp, ILzBaseOFTV2, ILzCommonOFT, ILzOFTReceiverV2} from "@abracadabra-oftv2/interfaces/ILayerZero.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {OwnableOperators} from "/mixins/OwnableOperators.sol";
import {SpellPowerStaking} from "/staking/SpellPowerStaking.sol";
import {RewardHandlerParams} from "/staking/MultiRewards.sol";
import {TokenLocker} from "/periphery/TokenLocker.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

enum CrosschainActions {
    MINT_AND_STAKE_BOUNDSPELL,
    STAKE_BOUNDSPELL
}

struct Payload {
    CrosschainActions action;
    bytes data;
}

struct MintBoundSpellAndStakeParams {
    address user;
    RewardHandlerParams rewardHandlerParams;
}

struct StakeBoundSpellParams {
    address user;
}

uint16 constant LZ_HUB_CHAIN_ID = 110; // Arbitrum
uint8 constant PT_SEND = 0;
uint8 constant PT_SEND_AND_CALL = 1;
uint8 constant MESSAGE_VERSION = 1;

contract BoundSpellActionSender is OwnableOperators, Pausable {
    using SafeTransferLib for address;

    event LogRescued(address token, uint256 amount, address to);
    event LogGasPerActionSet(CrosschainActions action, uint64 gas);

    error ErrInvalidAction();
    error ErrInvalidAmount();

    address public immutable spell; //Native Spell on Mainnet and SpellV2 on other chains
    address public immutable bSpell;

    ILzOFTV2 public immutable spellOft;
    ILzOFTV2 public immutable bSpellOft;

    mapping(CrosschainActions => uint64) public gasPerAction;

    constructor(ILzOFTV2 _spellOft, ILzOFTV2 _bSpellOft, address _owner) {
        spellOft = _spellOft;
        bSpellOft = _bSpellOft;

        spell = ILzBaseOFTV2(address(_spellOft)).innerToken();
        bSpell = ILzBaseOFTV2(address(_bSpellOft)).innerToken();

        // Spell is native on mainnet and needs to be approved for the OFTV2 contract proxy
        if (block.chainid == 1) {
            spell.safeApprove(address(_spellOft), type(uint256).max);
        }

        _initializeOwner(_owner);
    }

    //////////////////////////////////////////////////////////////////////////////////////////////
    /// VIEWS
    //////////////////////////////////////////////////////////////////////////////////////////////

    function estimate(CrosschainActions _action) external view returns (uint256 /*fee*/, uint256 /*unused*/) {
        uint64 dstGasForCall = gasPerAction[_action];
        ILzOFTV2 oft;
        bytes memory payload;

        if (_action == CrosschainActions.MINT_AND_STAKE_BOUNDSPELL) {
            oft = spellOft;
            bytes memory params = abi.encode(MintBoundSpellAndStakeParams(msg.sender, RewardHandlerParams("", 0)));
            payload = abi.encode(Payload(_action, params));
        } else if (_action == CrosschainActions.STAKE_BOUNDSPELL) {
            oft = bSpellOft;
            bytes memory params = abi.encode(StakeBoundSpellParams(msg.sender));
            payload = abi.encode(Payload(_action, params));
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

    function send(CrosschainActions _action, uint256 _amount) external payable whenNotPaused {
        if (_amount == 0) {
            revert ErrInvalidAmount();
        }

        uint64 dstGasForCall = gasPerAction[_action];

        if (_action == CrosschainActions.MINT_AND_STAKE_BOUNDSPELL) {
            _sendMintAndStakeBoundSpell(_amount, msg.sender, dstGasForCall);
        } else if (_action == CrosschainActions.STAKE_BOUNDSPELL) {
            _sendStakeBoundSpell(_amount, msg.sender, dstGasForCall);
        } else {
            revert ErrInvalidAction();
        }
    }

    //////////////////////////////////////////////////////////////////////////////////////////////
    /// OPERATORS
    //////////////////////////////////////////////////////////////////////////////////////////////

    function pause() external onlyOperators {
        _pause();
    }

    function unpause() external onlyOperators {
        _unpause();
    }

    //////////////////////////////////////////////////////////////////////////////////////////////
    /// ADMIN
    //////////////////////////////////////////////////////////////////////////////////////////////

    function rescue(address token, uint256 amount, address to) external onlyOwner {
        token.safeTransfer(to, amount);
        emit LogRescued(token, amount, to);
    }

    function setGasPerAction(CrosschainActions _action, uint64 _gas) external onlyOwner {
        gasPerAction[_action] = _gas;
        emit LogGasPerActionSet(_action, _gas);
    }

    //////////////////////////////////////////////////////////////////////////////////
    // INTERNALS
    //////////////////////////////////////////////////////////////////////////////////

    function _sendMintAndStakeBoundSpell(uint256 _amount, address _user, uint64 dstGasForCall) internal {
        bytes memory params = abi.encode(MintBoundSpellAndStakeParams(_user, RewardHandlerParams("", 0)));
        bytes memory payload = abi.encode(Payload(CrosschainActions.MINT_AND_STAKE_BOUNDSPELL, params));

        uint256 minGas = ILzApp(address(spellOft)).minDstGasLookup(LZ_HUB_CHAIN_ID, MESSAGE_VERSION);

        spell.safeTransferFrom(msg.sender, address(this), _amount);

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

    function _sendStakeBoundSpell(uint256 _amount, address _user, uint64 dstGasForCall) internal {
        bytes memory params = abi.encode(StakeBoundSpellParams(_user));
        bytes memory payload = abi.encode(Payload(CrosschainActions.STAKE_BOUNDSPELL, params));

        uint256 minGas = ILzApp(address(bSpellOft)).minDstGasLookup(LZ_HUB_CHAIN_ID, MESSAGE_VERSION);

        bSpell.safeTransferFrom(msg.sender, address(this), _amount);
        bSpellOft.sendAndCall{value: msg.value}(
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

contract BoundSpellActionReceiver is ILzOFTReceiverV2, OwnableOperators, Pausable {
    using SafeTransferLib for address;

    event LogRescued(address token, uint256 amount, address to);
    error ErrInvalidSender();
    error ErrInvalidSourceChainId();
    error ErrInvalidAction();

    address public immutable spell;
    address public immutable bSpell;

    ILzOFTV2 public immutable spellOft;
    ILzOFTV2 public immutable bSpellOft;

    SpellPowerStaking public immutable spellPowerStaking;
    TokenLocker public immutable boundSpellLocker;

    /// @dev Assumes the remote address is the same address as this contract
    /// must be deployed with CREATE3
    bytes32 public immutable remoteSender = bytes32(uint256(uint160(address(this))));

    constructor(
        ILzOFTV2 _spellOft,
        ILzOFTV2 _bSpellOft,
        SpellPowerStaking _spellPowerStaking,
        TokenLocker _boundSpellLocker,
        address _owner
    ) {
        spellOft = _spellOft;
        bSpellOft = _bSpellOft;
        spellPowerStaking = _spellPowerStaking;
        boundSpellLocker = _boundSpellLocker;

        spell = ILzBaseOFTV2(address(_spellOft)).innerToken();
        bSpell = ILzBaseOFTV2(address(_bSpellOft)).innerToken();

        spell.safeApprove(address(boundSpellLocker), type(uint256).max);
        bSpell.safeApprove(address(spellPowerStaking), type(uint256).max);

        _initializeOwner(_owner);
    }

    function onOFTReceived(
        uint16 _srcChainId, // Any chains except Arbitrum
        bytes calldata, // [ignored] _srcAddress: Remote OFT, using msg.sender against local oft to validate instead
        uint64, // [ignored] _nonce
        bytes32 _from, // BoundSpellActionSender
        uint256 _amount,
        bytes calldata _payload // (CrosschainActions action, address user, RewardHandlerParams rewardHandlerParams)
    ) external override whenNotPaused {
        if (msg.sender != address(spellOft) && msg.sender != address(bSpellOft)) {
            revert ErrInvalidSender();
        }
        if (_srcChainId == LZ_HUB_CHAIN_ID) {
            revert ErrInvalidSourceChainId();
        }
        if (_from != remoteSender) {
            revert ErrInvalidSender();
        }

        Payload memory payload = abi.decode(_payload, (Payload));
        if (payload.action == CrosschainActions.MINT_AND_STAKE_BOUNDSPELL) {
            MintBoundSpellAndStakeParams memory mintBoundSpellParams = abi.decode(payload.data, (MintBoundSpellAndStakeParams));
            _handleMintBoundSpellAndStake(_amount, mintBoundSpellParams);
        } else if (payload.action == CrosschainActions.STAKE_BOUNDSPELL) {
            StakeBoundSpellParams memory stakeBoundSpellParams = abi.decode(payload.data, (StakeBoundSpellParams));
            _handleStakeBoundSpell(_amount, stakeBoundSpellParams);
        } else {
            revert ErrInvalidAction();
        }
    }

    //////////////////////////////////////////////////////////////////////////////////////////////
    /// OPERATORS
    //////////////////////////////////////////////////////////////////////////////////////////////

    function pause() external onlyOperators {
        _pause();
    }

    function unpause() external onlyOperators {
        _unpause();
    }

    //////////////////////////////////////////////////////////////////////////////////////////////
    /// ADMIN
    //////////////////////////////////////////////////////////////////////////////////////////////

    function rescue(address token, uint256 amount, address to) external onlyOwner {
        token.safeTransfer(to, amount);
        emit LogRescued(token, amount, to);
    }

    //////////////////////////////////////////////////////////////////////////////////////////////
    /// INTERNALS
    //////////////////////////////////////////////////////////////////////////////////////////////

    function _handleMintBoundSpellAndStake(uint256 _amount, MintBoundSpellAndStakeParams memory _params) internal {
        boundSpellLocker.mint(_amount, address(this));
        spellPowerStaking.stakeFor(_params.user, _amount);
    }

    function _handleStakeBoundSpell(uint256 _amount, StakeBoundSpellParams memory _params) internal {
        spellPowerStaking.stakeFor(_params.user, _amount);
    }
}
