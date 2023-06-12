// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/BoringOwnable.sol";
import "BoringSolidity/libraries/BoringERC20.sol";
import "interfaces/ILzOFTV2.sol";
import "interfaces/IBentoBoxV1.sol";
import "interfaces/ICauldronV1.sol";
import "interfaces/ICauldronV2.sol";
import "libraries/SafeApprove.sol";
import "mixins/Operatable.sol";

/// @notice Responsible of withdrawing MIM fees from Cauldron and in case of altchains, bridge
/// MIM inside this contract to mainnet CauldronFeeWithdrawer
contract CauldronFeeWithdrawer is Operatable {
    using BoringERC20 for IERC20;
    using SafeApprove for IERC20;

    event LogMimWithdrawn(IBentoBoxV1 indexed bentoBox, uint256 amount);
    event LogMimTotalWithdrawn(uint256 amount);
    event LogMimProviderChanged(address indexed previous, address indexed current);
    event LogBentoBoxChanged(IBentoBoxV1 indexed bentoBox, bool previous, bool current);
    event LogCauldronChanged(address indexed cauldron, bool previous, bool current);
    event LogBridgeRecipientChanged(bytes32 indexed previous, bytes32 indexed current);

    error ErrInvalidFeeTo(address masterContract);

    struct CauldronInfo {
        address cauldron;
        address masterContract;
        IBentoBoxV1 bentoBox;
        uint8 version;
    }

    uint16 public constant LZ_MAINNET_CHAINID = 101;

    mapping(address => address) public feeToOverrides;
    IERC20 public immutable mim;
    ILzOFTV2 public immutable lzOftv2;
    bytes32 public bridgeRecipient;
    address public mimProvider;

    CauldronInfo[] public cauldronInfos;
    IBentoBoxV1[] public bentoBoxes;

    constructor(IERC20 _mim, ILzOFTV2 _lzOftv2, bytes32 _bridgeRecipient, address _mimProvider) {
        mim = _mim;
        lzOftv2 = _lzOftv2;
        bridgeRecipient = _bridgeRecipient;
        mimProvider = _mimProvider;
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
            (uint256 amount, ) = bentoBoxes[i].withdraw(mim, address(this), address(this), 0, share);
            totalAmount += amount;

            emit LogMimWithdrawn(bentoBoxes[i], amount);
        }
    }

    function bridge(uint256 amount, uint256 lzFee, bytes memory adapterParams) external onlyOperators {
        _bridge(amount, lzFee, adapterParams);
    }

    function _bridge(uint256 amount, uint256 lzFee, bytes memory adapterParams) internal {
        ILzCommonOFT.LzCallParams memory lzCallParams = ILzCommonOFT.LzCallParams({
            refundAddress: payable(address(this)),
            zroPaymentAddress: address(0),
            adapterParams: adapterParams
        });

        lzOftv2.sendFrom{value: lzFee}(
            address(this), // 'from' address to send tokens
            LZ_MAINNET_CHAINID, // mainnet remote LayerZero chainId
            bridgeRecipient, // 'to' address to send tokens
            amount, // amount of tokens to send (in wei)
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

    function setMimProvider(address _mimProvider) external onlyOwner {
        emit LogMimProviderChanged(mimProvider, _mimProvider);
        mimProvider = _mimProvider;
    }

    function setBridgeRecipient(address _bridgeRecipient) external onlyOwner {
        bytes32 previousBridgeRecipient = bridgeRecipient;
        bridgeRecipient = bytes32(uint256(uint160(_bridgeRecipient)));
        emit LogBridgeRecipientChanged(previousBridgeRecipient, bridgeRecipient);
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

    function approveMim(address spender, uint256 amount) external onlyOwner {
        mim.safeApprove(spender, amount);
    }

    function execute(address to, uint256 value, bytes calldata data) external onlyOwner returns (bool success, bytes memory result) {
        // solhint-disable-next-line avoid-low-level-calls
        (success, result) = to.call{value: value}(data);
    }
}
