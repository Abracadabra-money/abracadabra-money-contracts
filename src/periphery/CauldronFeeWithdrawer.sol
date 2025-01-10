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
import {CauldronRegistry, CauldronInfo} from "/periphery/CauldronRegistry.sol";
import {FeeCollectable} from "/mixins/FeeCollectable.sol";

/// @notice Withdraws MIM fees from Cauldrons and distribute them to SpellPower stakers
/// All chains have this contract deployed with the same address.
/// This is assuming MIM is using LayerZero OFTv2 EndpointV1.
contract CauldronFeeWithdrawer is FeeCollectable, OwnableOperators, UUPSUpgradeable, Initializable {
    using SafeTransferLib for address;

    event LogMimWithdrawn(address indexed box, uint256 amount);
    event LogMimTotalWithdrawn(uint256 amount);
    event LogFeeToOverrideChanged(address indexed cauldron, address previous, address current);
    event LogMimProviderChanged(address previous, address current);
    event LogStakingChanged(address indexed previous, address indexed current);
    event LogRegistryChanged(address indexed previous, address indexed current);
    event LogFeeDistributed(uint256 amount, uint256 userAmount, uint256 feeAmount);

    error ErrInvalidFeeTo(address masterContract);
    error ErrNotEnoughNativeTokenToCoverFee();
    error ErrInvalidChainId();

    uint16 public constant LZ_HUB_CHAINID = 110; // Arbitrum EndpointV1 ChainId
    uint256 public constant HUB_CHAINID = 42161; // Arbitrum ChainId

    address public immutable mim;
    ILzOFTV2 public immutable oft;

    mapping(address cauldron => address feeTo) public feeToOverrides;
    address public mimProvider;
    CauldronRegistry public registry;
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

    function cauldronInfosCount() external view returns (uint256) {
        return registry.length();
    }

    function cauldronInfo(address cauldron) external view returns (CauldronInfo memory) {
        return registry.get(cauldron);
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
    /// OPERATORS
    //////////////////////////////////////////////////////////////////////////////////////////////

    function withdraw(uint256[] calldata cauldronsIndices) external onlyOperators returns (uint256 totalAmount) {
        address[] memory boxes = new address[](cauldronsIndices.length);

        for (uint256 i = 0; i < cauldronsIndices.length; i++) {
            CauldronInfo memory info = registry.get(cauldronsIndices[i]);
            address masterContract = address(ICauldronV1(info.cauldron).masterContract());

            if (ICauldronV1(masterContract).feeTo() != address(this)) {
                revert ErrInvalidFeeTo(masterContract);
            }

            IBentoBoxLite box = IBentoBoxLite(ICauldronV1(info.cauldron).bentoBox());
            ICauldronV1(info.cauldron).accrue();

            uint256 feesEarned;
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

            boxes[i] = address(box);
        }

        // Withdraw MIMs from all the bentoBoxes to this contract
        for (uint256 i = 0; i < boxes.length; i++) {
            uint256 share = IBentoBoxLite(boxes[i]).balanceOf(mim, address(this));
            if (share > 0) {
                (uint256 amountWithdrawn, ) = IBentoBoxLite(boxes[i]).withdraw(mim, address(this), address(this), 0, share);
                totalAmount += amountWithdrawn;

                emit LogMimWithdrawn(boxes[i], amountWithdrawn);
            }
        }

        emit LogMimTotalWithdrawn(totalAmount);
    }

    function distribute(uint256 amount) external onlyOperators {
        if (block.chainid != HUB_CHAINID) {
            revert ErrInvalidChainId();
        }

        (uint256 userAmount, uint256 treasuryAmount) = _calculateFees(amount);

        if (treasuryAmount > 0) {
            mim.safeTransfer(feeCollector, treasuryAmount);
        }

        if (userAmount > 0) {
            IMultiRewardsStaking(staking).notifyRewardAmount(mim, userAmount);
        }

        emit LogFeeDistributed(amount, userAmount, treasuryAmount);
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

        // MIM is native on mainnet, so we need to approve the oft proxy to bridge the amount
        if (block.chainid == 1) {
            mim.safeApprove(address(oft), amount);
        }

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

    function setRegistry(address _registry) external onlyOwner {
        emit LogRegistryChanged(address(registry), _registry);
        registry = CauldronRegistry(_registry);
    }

    function setMimProvider(address _mimProvider) external onlyOwner {
        emit LogMimProviderChanged(mimProvider, _mimProvider);
        mimProvider = _mimProvider;
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

    function _authorizeUpgrade(address /*newImplementation*/) internal virtual override {
        _checkOwner();
    }

    function _isFeeOperator(address account) internal view override returns (bool) {
        return owner == account;
    }
}
