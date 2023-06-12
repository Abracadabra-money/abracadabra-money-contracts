// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/BoringOwnable.sol";
import "BoringSolidity/libraries/BoringERC20.sol";
import "interfaces/ILzOFTV2.sol";
import "interfaces/IBentoBoxV1.sol";
import "interfaces/ICauldronV1.sol";
import "interfaces/ICauldronV2.sol";
import "interfaces/ICauldronFeeWithdrawReporter.sol";
import "libraries/SafeApprove.sol";
import "mixins/Operatable.sol";

contract DefaultCauldronFeeWithdrawerReporter is ICauldronFeeWithdrawReporter {
    IERC20 public immutable spell;
    address public immutable mSpell;

    constructor(IERC20 _spell, address _mSpell) {
        spell = _spell;
        mSpell = _mSpell;
    }

    function getPayload() external view override returns (bytes memory) {
        return abi.encode(uint128(spell.balanceOf(mSpell)));
    }
}

/// @notice Responsible of withdrawing MIM fees from Cauldron and in case of altchains, bridge
/// MIM inside this contract to mainnet CauldronFeeWithdrawer
contract CauldronFeeWithdrawer is Operatable {
    using BoringERC20 for IERC20;
    using SafeApprove for IERC20;

    event LogMimWithdrawn(IBentoBoxV1 indexed bentoBox, uint256 amount);
    event LogMimTotalWithdrawn(uint256 amount);
    event LogBentoBoxChanged(IBentoBoxV1 indexed bentoBox, bool previous, bool current);
    event LogCauldronChanged(address indexed cauldron, bool previous, bool current);
    event LogParametersChanged(
        address mimProvider,
        bytes32 bridgeRecipient,
        address mimWithdrawRecipient,
        ICauldronFeeWithdrawReporter reporter
    );

    error ErrInvalidFeeTo(address masterContract);

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
    address public mimWithdrawRecipient;
    bytes32 public bridgeRecipient;
    address public mimProvider;

    // used to attach extra info when bridging MIM
    ICauldronFeeWithdrawReporter reporter;

    CauldronInfo[] public cauldronInfos;
    IBentoBoxV1[] public bentoBoxes;

    constructor(IERC20 _mim, ILzOFTV2 _lzOftv2, address _mimProvider) {
        mim = _mim;
        lzOftv2 = _lzOftv2;
        mimProvider = _mimProvider;

        /// @dev By default withdraw MIM from bentoBox to this contract because they will need
        /// to get bridge from altchains to mainnet CauldronFeeWithdrawer.
        /// On mainnet, this will be withdrawn to CauldronFeeWithdrawer directly.
        mimWithdrawRecipient = address(this);
    }

    function bentoBoxesCount() external view returns (uint256) {
        return bentoBoxes.length;
    }

    function cauldronInfosCount() external view returns (uint256) {
        return cauldronInfos.length;
    }

    function withdraw() external {
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

        uint256 amount = withdrawAllMimFromBentoBoxes();
        emit LogMimTotalWithdrawn(amount);
    }

    function withdrawAllMimFromBentoBoxes() public returns (uint256 totalAmount) {
        for (uint256 i = 0; i < bentoBoxes.length; i++) {
            uint256 share = bentoBoxes[i].balanceOf(mim, address(this));
            (uint256 amount, ) = bentoBoxes[i].withdraw(mim, address(this), mimWithdrawRecipient, 0, share);
            totalAmount += amount;

            emit LogMimWithdrawn(bentoBoxes[i], amount);
        }
    }

    function bridge(uint256 amount, uint256 fee, uint64 extraFee, bytes memory adapterParams) external onlyOperators {
        _bridge(amount, fee, extraFee, adapterParams);
    }

    function _bridge(uint256 amount, uint256 fee, uint64 extraFee, bytes memory adapterParams) internal {
        ILzCommonOFT.LzCallParams memory lzCallParams = ILzCommonOFT.LzCallParams({
            refundAddress: payable(address(this)),
            zroPaymentAddress: address(0),
            adapterParams: adapterParams
        });

        lzOftv2.sendAndCall{value: fee}(
            address(this), // 'from' address to send tokens
            LZ_MAINNET_CHAINID, // mainnet remote LayerZero chainId
            bridgeRecipient, // 'to' address to send tokens
            amount, // amount of tokens to send (in wei)
            reporter.getPayload(), // mandatory payload
            extraFee,
            lzCallParams
        );
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

        emit LogCauldronChanged(cauldron, previousEnabled, enabled);
    }

    function setParameters(
        address _mimProvider,
        address _bridgeRecipient,
        address _mimWithdrawRecipient,
        ICauldronFeeWithdrawReporter _reporter
    ) external onlyOwner {
        mimProvider = _mimProvider;
        bridgeRecipient = bytes32(uint256(uint160(_bridgeRecipient)));
        mimWithdrawRecipient = _mimWithdrawRecipient;
        reporter = _reporter;

        emit LogParametersChanged(_mimProvider, bridgeRecipient, _mimWithdrawRecipient, _reporter);
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

        emit LogBentoBoxChanged(bentoBox, previousEnabled, enabled);
    }
}
