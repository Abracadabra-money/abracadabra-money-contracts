// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@solady/utils/UUPSUpgradeable.sol";
import {ILzOFTV2, ILzApp, ILzCommonOFT, ILzBaseOFTV2} from "@abracadabra-oftv2/interfaces/ILayerZero.sol";
import {IBentoBoxLite} from "/interfaces/IBentoBoxV1.sol";
import {ICauldronV1} from "/interfaces/ICauldronV1.sol";
import {ICauldronV2} from "/interfaces/ICauldronV2.sol";
import {OwnableOperators} from "/mixins/OwnableOperators.sol";
import {IMultiRewardsStaking} from "/interfaces/IMultiRewardsStaking.sol";

/// @notice Withdraws MIM fees from Cauldrons and distribute them to SpellPower stakers
/// All chains have this contract deployed with the same address.
/// This is assuming MIM is using LayerZero OFTv2 EndpointV1.
contract CauldronFeeWithdrawer is OwnableOperators, UUPSUpgradeable, Initializable {
    using SafeTransferLib for address;

    event LogMimWithdrawn(address indexed box, uint256 amount);
    event LogMimTotalWithdrawn(uint256 amount);
    event LogBentoBoxChanged(address indexed box, bool previous, bool current);
    event LogCauldronChanged(address indexed cauldron, bool previous, bool current);
    event LogFeeToOverrideChanged(address indexed cauldron, address previous, address current);
    event LogMimProviderChanged(address previous, address current);
    event LogStakingChanged(address indexed previous, address indexed current);

    error ErrInvalidFeeTo(address masterContract);
    error ErrNotEnoughNativeTokenToCoverFee();
    error ErrInvalidChainId();

    struct CauldronInfo {
        address cauldron;
        address masterContract;
        IBentoBoxLite box;
        uint8 version;
    }

    uint16 public constant LZ_HUB_CHAINID = 110; // Arbitrum EndpointV1 ChainId
    uint256 public constant HUB_CHAINID = 42161; // Arbitrum ChainId

    address public immutable mim;
    ILzOFTV2 public immutable oft;

    mapping(address => address) public feeToOverrides;
    address public mimProvider;
    CauldronInfo[] public cauldronInfos;
    address[] public bentoBoxes;
    IMultiRewardsStaking public staking;

    // allow to receive gas to cover bridging fees
    receive() external payable {}

    constructor(ILzOFTV2 _oft, address _owner) {
        _initializeOwner(_owner);

        mim = ILzBaseOFTV2(address(_oft)).innerToken();
        oft = _oft;

        _disableInitializers();
    }

    function initialize(address _owner) external initializer {
        _initializeOwner(_owner);
    }

    //////////////////////////////////////////////////////////////////////////////////////////////
    /// VIEWS
    //////////////////////////////////////////////////////////////////////////////////////////////

    function bentoBoxesCount() external view returns (uint256) {
        return bentoBoxes.length;
    }

    function cauldronInfosCount() external view returns (uint256) {
        return cauldronInfos.length;
    }

    function estimateBridgingFee(uint256 amount) external view returns (uint256 fee, uint256 gas) {
        gas = ILzApp(address(oft)).minDstGasLookup(LZ_HUB_CHAINID, 0 /* packet type for sendFrom */);
        (fee, ) = oft.estimateSendFee(
            LZ_HUB_CHAINID,
            bytes32(uint256(uint160(address(this)))),
            amount,
            false,
            abi.encodePacked(uint16(1), uint256(gas))
        );
    }

    //////////////////////////////////////////////////////////////////////////////////////////////
    /// PUBLIC
    //////////////////////////////////////////////////////////////////////////////////////////////

    function withdraw() external returns (uint256 amount) {
        for (uint256 i = 0; i < cauldronInfos.length; i++) {
            CauldronInfo memory info = cauldronInfos[i];

            // all registered cauldrons must have this contract as feeTo
            if (ICauldronV1(info.masterContract).feeTo() != address(this)) {
                revert ErrInvalidFeeTo(info.masterContract);
            }

            ICauldronV1(info.cauldron).accrue();
            uint256 feesEarned;
            IBentoBoxLite box = info.box;

            if (info.version == 1) {
                (, feesEarned) = ICauldronV1(info.cauldron).accrueInfo();
            } else if (info.version >= 2) {
                (, feesEarned, ) = ICauldronV2(info.cauldron).accrueInfo();
            }

            uint256 cauldronMimBalance = box.toAmount(mim, box.balanceOf(mim, info.cauldron), false);

            // in case the cauldron has more fees than the balance,
            // deposit the missing amount from the mimProvider.
            if (feesEarned > cauldronMimBalance) {
                uint256 remainingAmount = feesEarned - cauldronMimBalance;
                mim.safeTransferFrom(mimProvider, address(box), remainingAmount);
                box.deposit(mim, address(box), info.cauldron, remainingAmount, 0);
            }

            ICauldronV1(info.cauldron).withdrawFees();

            // redirect fees to override address when set
            address feeToOverride = feeToOverrides[info.cauldron];
            if (feeToOverride != address(0)) {
                box.transfer(mim, address(this), feeToOverride, box.toShare(mim, feesEarned, false));
            }
        }

        amount = _withdrawAllMimFromBentoBoxes();
        emit LogMimTotalWithdrawn(amount);
    }

    //////////////////////////////////////////////////////////////////////////////////////////////
    /// OPERATORS
    //////////////////////////////////////////////////////////////////////////////////////////////

    function distribute(uint256 amount) external onlyOperators {
        if (block.chainid != HUB_CHAINID) {
            revert ErrInvalidChainId();
        }

        IMultiRewardsStaking(staking).notifyRewardAmount(mim, amount);
    }

    function bridge(uint256 amount, uint256 fee, uint256 gas) external onlyOperators {
        // check if there is enough native token to cover the bridging fees
        if (fee > address(this).balance) {
            revert ErrNotEnoughNativeTokenToCoverFee();
        }

        ILzCommonOFT.LzCallParams memory lzCallParams = ILzCommonOFT.LzCallParams({
            refundAddress: payable(address(this)),
            zroPaymentAddress: address(0),
            adapterParams: abi.encodePacked(uint16(1), uint256(gas))
        });

        oft.sendFrom{value: fee}(
            address(this), // 'from' address to send tokens
            LZ_HUB_CHAINID, // Arbitrum remote LayerZero chainId
            bytes32(uint256(uint160(address(this)))), // all chains have this contract deployed with the same address
            amount, // amount of tokens to send (in wei)
            lzCallParams
        );
    }

    //////////////////////////////////////////////////////////////////////////////////////////////
    /// ADMIN
    //////////////////////////////////////////////////////////////////////////////////////////////

    function setFeeToOverride(address cauldron, address feeTo) external onlyOwner {
        emit LogFeeToOverrideChanged(cauldron, feeToOverrides[cauldron], feeTo);
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

    function setMimProvider(address _mimProvider) external onlyOwner {
        emit LogMimProviderChanged(mimProvider, _mimProvider);
        mimProvider = _mimProvider;
    }

    function setBentoBox(address box, bool enabled) external onlyOwner {
        bool previousEnabled;

        for (uint256 i = 0; i < bentoBoxes.length; i++) {
            if (bentoBoxes[i] == box) {
                bentoBoxes[i] = bentoBoxes[bentoBoxes.length - 1];
                bentoBoxes.pop();
                previousEnabled = true;
                break;
            }
        }

        if (enabled) {
            bentoBoxes.push(box);
        }

        emit LogBentoBoxChanged(box, previousEnabled, enabled);
    }

    function setStaking(address _staking) external onlyOwner {
        emit LogStakingChanged(address(staking), _staking);

        if (address(staking) != address(0)) {
            mim.safeApprove(address(staking), 0);
        }

        mim.safeApprove(_staking, type(uint256).max);
        staking = IMultiRewardsStaking(_staking);
    }

    /// @notice Emergency function to execute a call on the contract, for example to rescue tokens or native tokens
    function execute(address to, uint256 value, bytes calldata data) external onlyOwner returns (bytes memory result) {
        return Address.functionCallWithValue(to, data, value);
    }

    //////////////////////////////////////////////////////////////////////////////////////////////
    /// INTERNAL
    //////////////////////////////////////////////////////////////////////////////////////////////

    function _setCauldron(address cauldron, uint8 version, bool enabled) internal {
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
                    box: IBentoBoxLite(address(ICauldronV1(cauldron).bentoBox())),
                    version: version
                })
            );
        }

        emit LogCauldronChanged(cauldron, previousEnabled, enabled);
    }

    function _withdrawAllMimFromBentoBoxes() internal returns (uint256 totalAmount) {
        for (uint256 i = 0; i < bentoBoxes.length; i++) {
            uint256 share = IBentoBoxLite(bentoBoxes[i]).balanceOf(mim, address(this));
            (uint256 amount, ) = IBentoBoxLite(bentoBoxes[i]).withdraw(mim, address(this), address(this), 0, share);
            totalAmount += amount;

            emit LogMimWithdrawn(bentoBoxes[i], amount);
        }
    }

    function _authorizeUpgrade(address /*newImplementation*/) internal virtual override {
        _checkOwner();
    }
}
