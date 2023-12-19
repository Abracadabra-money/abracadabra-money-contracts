// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {BoringERC20} from "BoringSolidity/libraries/BoringERC20.sol";
import {ILzOFTV2, ILzApp, ILzCommonOFT} from "interfaces/ILayerZero.sol";
import {IBentoBoxV1} from "interfaces/IBentoBoxV1.sol";
import {ICauldronV1} from "interfaces/ICauldronV1.sol";
import {ICauldronV2} from "interfaces/ICauldronV2.sol";
import {SafeApproveLib} from "libraries/SafeApproveLib.sol";
import {OperatableV2} from "mixins/OperatableV2.sol";

library CauldronFeeWithdrawWithdrawerEvents {
    event LogMimWithdrawn(IBentoBoxV1 indexed bentoBox, uint256 amount);
    event LogMimTotalWithdrawn(uint256 amount);
    event LogBentoBoxChanged(IBentoBoxV1 indexed bentoBox, bool previous, bool current);
    event LogCauldronChanged(address indexed cauldron, bool previous, bool current);
    event LogParametersChanged(address mimProvider, bytes32 bridgeRecipient, address mimWithdrawRecipient);
    event LogFeeToOverrideChanged(address indexed cauldron, address previous, address current);
}

/// @notice Responsible of withdrawing MIM fees from Cauldron and in case of altchains, bridge
/// MIM inside this contract to mainnet CauldronFeeWithdrawer
contract CauldronFeeWithdrawer is OperatableV2 {
    using BoringERC20 for IERC20;
    using SafeApproveLib for IERC20;

    error ErrInvalidFeeTo(address masterContract);
    error ErrNotEnoughNativeTokenToCoverFee();

    struct CauldronInfo {
        address cauldron;
        address masterContract;
        IBentoBoxV1 bentoBox;
        uint8 version;
    }

    uint16 public constant LZ_MAINNET_CHAINID = 101;
    IERC20 public immutable mim;
    ILzOFTV2 public immutable lzOftv2;

    mapping(address => address) public feeToOverrides;

    /// @dev By default withdraw MIM from bentoBox to this contract because they will need
    /// to get bridge from altchains to mainnet SpellStakingRewardDistributor.
    /// On mainnet, this should be withdrawn to SpellStakingRewardDistributor directly.
    address public mimWithdrawRecipient;
    bytes32 public bridgeRecipient;
    address public mimProvider;

    CauldronInfo[] public cauldronInfos;
    IBentoBoxV1[] public bentoBoxes;

    constructor(address _owner, IERC20 _mim, ILzOFTV2 _lzOftv2) OperatableV2(_owner) {
        mim = _mim;
        lzOftv2 = _lzOftv2;
    }

    receive() external payable {}

    function bentoBoxesCount() external view returns (uint256) {
        return bentoBoxes.length;
    }

    function cauldronInfosCount() external view returns (uint256) {
        return cauldronInfos.length;
    }

    function withdraw() external returns (uint256 amount) {
        for (uint256 i = 0; i < cauldronInfos.length; i++) {
            CauldronInfo memory info = cauldronInfos[i];

            if (ICauldronV1(info.masterContract).feeTo() != address(this)) {
                revert ErrInvalidFeeTo(info.masterContract);
            }

            ICauldronV1(info.cauldron).accrue();
            uint256 feesEarned;
            IBentoBoxV1 bentoBox = info.bentoBox;

            if (info.version == 1) {
                (, feesEarned) = ICauldronV1(info.cauldron).accrueInfo();
            } else if (info.version >= 2) {
                (, feesEarned, ) = ICauldronV2(info.cauldron).accrueInfo();
            }

            uint256 cauldronMimAmount = bentoBox.toAmount(mim, bentoBox.balanceOf(mim, info.cauldron), false);
            if (feesEarned > cauldronMimAmount) {
                // only transfer the required mim amount
                uint256 diff = feesEarned - cauldronMimAmount;
                mim.safeTransferFrom(mimProvider, address(bentoBox), diff);
                bentoBox.deposit(mim, address(bentoBox), info.cauldron, diff, 0);
            }

            ICauldronV1(info.cauldron).withdrawFees();

            // redirect fees to override address if set
            address feeToOverride = feeToOverrides[info.cauldron];
            if (feeToOverride != address(0)) {
                info.bentoBox.transfer(mim, address(this), feeToOverride, bentoBox.toShare(mim, feesEarned, false));
            }
        }

        amount = _withdrawAllMimFromBentoBoxes();
        emit CauldronFeeWithdrawWithdrawerEvents.LogMimTotalWithdrawn(amount);
    }

    function estimateBridgingFee(uint256 amount) external view returns (uint256 fee, uint256 gas) {
        gas = ILzApp(address(lzOftv2)).minDstGasLookup(LZ_MAINNET_CHAINID, 0 /* packet type for sendFrom */);
        (fee, ) = lzOftv2.estimateSendFee(LZ_MAINNET_CHAINID, bridgeRecipient, amount, false, abi.encodePacked(uint16(1), uint256(gas)));
    }

    function bridge(uint256 amount, uint256 fee, uint256 gas) external onlyOperators {
        // optionnal check for convenience
        // check if there is enough native token to cover the bridging fees
        if (fee > address(this).balance) {
            revert ErrNotEnoughNativeTokenToCoverFee();
        }

        ILzCommonOFT.LzCallParams memory lzCallParams = ILzCommonOFT.LzCallParams({
            refundAddress: payable(address(this)),
            zroPaymentAddress: address(0),
            adapterParams: abi.encodePacked(uint16(1), uint256(gas))
        });

        lzOftv2.sendFrom{value: fee}(
            address(this), // 'from' address to send tokens
            LZ_MAINNET_CHAINID, // mainnet remote LayerZero chainId
            bridgeRecipient, // 'to' address to send tokens
            amount, // amount of tokens to send (in wei)
            lzCallParams
        );
    }

    function setFeeToOverride(address cauldron, address feeTo) external onlyOwner {
        emit CauldronFeeWithdrawWithdrawerEvents.LogFeeToOverrideChanged(cauldron, feeToOverrides[cauldron], feeTo);
        feeToOverrides[cauldron] = feeTo;
    }

    function setCauldron(address cauldron, uint8 version, bool enabled) external onlyOwner {
        _setCauldron(cauldron, version, enabled);
    }

    function setCauldrons(address[] memory cauldrons, uint8[] memory versions, bool[] memory enabled) external onlyOwner {
        for (uint256 i = 0; i < cauldrons.length; i++) {
            _setCauldron(cauldrons[i], versions[i], enabled[i]);
        }
    }

    function _setCauldron(address cauldron, uint8 version, bool enabled) private {
        bool previousEnabled;

        for (uint256 i = 0; i < cauldronInfos.length; i++) {
            if (cauldronInfos[i].cauldron == cauldron) {
                cauldronInfos[i] = cauldronInfos[cauldronInfos.length - 1];
                cauldronInfos.pop();
                break;
            }
        }

        if (enabled) {
            cauldronInfos.push(
                CauldronInfo({
                    cauldron: cauldron,
                    masterContract: address(ICauldronV1(cauldron).masterContract()),
                    bentoBox: IBentoBoxV1(ICauldronV1(cauldron).bentoBox()),
                    version: version
                })
            );
        }

        emit CauldronFeeWithdrawWithdrawerEvents.LogCauldronChanged(cauldron, previousEnabled, enabled);
    }

    function _withdrawAllMimFromBentoBoxes() private returns (uint256 totalAmount) {
        for (uint256 i = 0; i < bentoBoxes.length; i++) {
            uint256 share = bentoBoxes[i].balanceOf(mim, address(this));
            (uint256 amount, ) = bentoBoxes[i].withdraw(mim, address(this), mimWithdrawRecipient, 0, share);
            totalAmount += amount;

            emit CauldronFeeWithdrawWithdrawerEvents.LogMimWithdrawn(bentoBoxes[i], amount);
        }
    }

    function setParameters(address _mimProvider, address _bridgeRecipient, address _mimWithdrawRecipient) external onlyOwner {
        mimProvider = _mimProvider;
        bridgeRecipient = bytes32(uint256(uint160(_bridgeRecipient)));
        mimWithdrawRecipient = _mimWithdrawRecipient;

        emit CauldronFeeWithdrawWithdrawerEvents.LogParametersChanged(_mimProvider, bridgeRecipient, _mimWithdrawRecipient);
    }

    function setBentoBox(IBentoBoxV1 bentoBox, bool enabled) external onlyOwner {
        bool previousEnabled;

        for (uint256 i = 0; i < bentoBoxes.length; i++) {
            if (bentoBoxes[i] == bentoBox) {
                bentoBoxes[i] = bentoBoxes[bentoBoxes.length - 1];
                bentoBoxes.pop();
                previousEnabled = true;
                break;
            }
        }

        if (enabled) {
            bentoBoxes.push(bentoBox);
        }

        emit CauldronFeeWithdrawWithdrawerEvents.LogBentoBoxChanged(bentoBox, previousEnabled, enabled);
    }

    ////////////////////////////////////////////////////////
    // Emergency Functions
    ////////////////////////////////////////////////////////

    function rescueTokens(IERC20 token, address to, uint256 amount) external onlyOwner {
        token.safeTransfer(to, amount);
    }

    function execute(address to, uint256 value, bytes calldata data) external onlyOwner returns (bool success, bytes memory result) {
        // solhint-disable-next-line avoid-low-level-calls
        (success, result) = to.call{value: value}(data);
    }
}
