// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {ILayerZeroEndpointV2, MessagingFee} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {ILayerZeroComposer} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroComposer.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/oft-evm/contracts/libs/OFTComposeMsgCodec.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {OwnableOperators} from "/mixins/OwnableOperators.sol";
import {SpellPowerStaking} from "/staking/SpellPowerStaking.sol";
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

uint16 constant LZ_HUB_CHAIN_ID = 30110; // Arbitrum
uint8 constant MAINNET_CHAIN_ID = 1;
uint16 constant SEND_AND_CALL = 2;

contract BoundSpellActionSender is OwnableOperators, Pausable {
    using SafeTransferLib for address;

    event LogRescued(address token, uint256 amount, address to);
    event LogGasPerActionSet(CrosschainActions action, uint64 gas);

    error ErrInvalidAction();
    error ErrInvalidAmount();

    address public immutable spell; //Native Spell on Mainnet and SpellV2 on other chains
    address public immutable bSpell;

    ILayerZeroEndpointV2 public immutable spellOft;
    ILayerZeroEndpointV2 public immutable bSpellOft;

    mapping(CrosschainActions => uint64) public gasPerAction;

    constructor(ILayerZeroEndpointV2 _spellOft, ILayerZeroEndpointV2 _bSpellOft, address _owner) {
        spellOft = _spellOft;
        bSpellOft = _bSpellOft;

        spell = ILayerZeroEndpointV2(address(_spellOft)).token();
        bSpell = ILayerZeroEndpointV2(address(_bSpellOft)).token();

        // Spell is native on mainnet and needs to be approved for the adapter contract
        if (block.chainid == MAINNET_CHAIN_ID) {
            spell.safeApprove(address(_spellOft), type(uint256).max);
        }

        _initializeOwner(_owner);
    }

    //////////////////////////////////////////////////////////////////////////////////////////////
    /// VIEWS
    //////////////////////////////////////////////////////////////////////////////////////////////

    function estimate(CrosschainActions _action) external view returns (uint256 /*fee*/, uint256 /*unused*/) {
        (ILayerZeroEndpointV2 oft, bytes memory payload, bytes memory extraOptions) = _buildPayloadAndParamerters(_action, msg.sender);

        SendParam memory sendParam = SendParam({
            dstEid: LZ_HUB_CHAIN_ID,
            to: bytes32(uint256(uint160(address(this)))),
            amountLD: 1,
            minAmountLD: 1,
            extraOptions: extraOptions,
            composeMsg: payload,
            oftCmd: new bytes(0)
        });

        return oft.quoteSend(sendParam, false);
    }

    //////////////////////////////////////////////////////////////////////////////////////////////
    /// PERMISSIONLESS
    //////////////////////////////////////////////////////////////////////////////////////////////

    function send(CrosschainActions _action, uint256 _amount) external payable whenNotPaused {
        if (_amount == 0) {
            revert ErrInvalidAmount();
        }
        (ILayerZeroEndpointV2 oft, bytes memory payload, uint64 dstGasForCall, bytes memory extraOptions) = _buildPayloadAndParamerters(
            _action,
            msg.sender
        );

        if (_action == CrosschainActions.MINT_AND_STAKE_BOUNDSPELL) {
            spell.safeTransferFrom(msg.sender, address(this), _amount);
        } else if (_action == CrosschainActions.STAKE_BOUNDSPELL) {
            bSpell.safeTransferFrom(msg.sender, address(this), _amount);
        } else {
            revert ErrInvalidAction();
        }

        SendParam memory sendParam = SendParam({
            dstEid: LZ_HUB_CHAIN_ID,
            to: bytes32(uint256(uint160(address(this)))),
            amountLD: _amount,
            minAmountLD: _amount,
            extraOptions: extraOptions,
            composeMsg: payload,
            oftCmd: new bytes(0)
        });

        MessagingFee memory fee = oft.quoteSend(sendParam, false);
        oft.send{value: msg.value}(sendParam, fee, msg.sender);
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

    function _buildPayloadAndParamerters(
        CrosschainActions _action,
        address _recipient
    ) internal pure returns (ILayerZeroEndpointV2 oft, bytes memory payload, bytes memory extraOptions) {
        if (_action == CrosschainActions.MINT_AND_STAKE_BOUNDSPELL) {
            oft = spellOft;
        } else if (_action == CrosschainActions.STAKE_BOUNDSPELL) {
            oft = bSpellOft;
        } else {
            revert ErrInvalidAction();
        }

        payload = abi.encode(Payload(_action, abi.encode(_recipient))); // action -> recipient
        extraOptions = OptionsBuilder.newOptions().addExecutorLzComposeOption(0, gasPerAction[_action], 0);
    }
}

contract BoundSpellActionReceiver is ILayerZeroComposer, OwnableOperators, Pausable {
    using SafeTransferLib for address;

    event LogRescued(address token, uint256 amount, address to);
    error ErrInvalidSender();
    error ErrInvalidSourceChainId();
    error ErrInvalidAction();

    address public immutable spell;
    address public immutable bSpell;

    ILayerZeroEndpointV2 public immutable spellOft;
    ILayerZeroEndpointV2 public immutable bSpellOft;

    SpellPowerStaking public immutable spellPowerStaking;
    TokenLocker public immutable boundSpellLocker;

    /// @dev Assumes the remote address is the same address as this contract
    /// must be deployed with CREATE3
    bytes32 public immutable remoteSender = bytes32(uint256(uint160(address(this))));

    ILayerZeroEndpointV2 public immutable endpoint;

    constructor(
        ILayerZeroEndpointV2 _endpoint,
        ILayerZeroEndpointV2 _spellOft,
        ILayerZeroEndpointV2 _bSpellOft,
        SpellPowerStaking _spellPowerStaking,
        TokenLocker _boundSpellLocker,
        address _owner
    ) {
        endpoint = _endpoint;
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
        bytes calldata _payload // (CrosschainActions action, address user)
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

    /// @dev The OFT sends a compose message in the following format:
    /// bytes memory composeMsg = OFTComposeMsgCodec.encode(
    ///     _origin.nonce,
    ///     _origin.srcEid,
    ///     amountReceivedLD,
    ///     _message.composeMsg()
    /// );
    function lzCompose(
        address _from,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) external payable override {
        // Both the sender and the receiver are the same address
        // because they are deployed with the same CREATE3 salt
        if (_from != address(this) || msg.sender != address(endpoint)) {
            revert ErrInvalidSender();
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
