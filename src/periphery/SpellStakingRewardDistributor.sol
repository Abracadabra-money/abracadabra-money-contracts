// SPDX-License-Identifier: MIT
/// solhint-disable not-rely-on-time
pragma solidity >=0.8.0;

import "BoringSolidity/ERC20.sol";
import "BoringSolidity/libraries/BoringERC20.sol";
import "mixins/OperatableV2.sol";
import "interfaces/ILzReceiver.sol";
import "interfaces/ILzApp.sol";
import "interfaces/ILzOFTV2.sol";
import "interfaces/ILzOFTReceiverV2.sol";
import "forge-std/console2.sol";

/// @notice Responsible of sending MIM rewards to MSpell staking and sSPELL buyback contract.
/// @dev Mainnet Only
contract SpellStakingRewardDistributor is OperatableV2, ILzOFTReceiverV2 {
    using BoringERC20 for IERC20;

    event LogSetOperator(address indexed operator, bool status);
    event LogAddRecipient(address indexed recipient, uint256 chainId, uint256 chainIdLZ);
    event LogBridgeToRecipient(address indexed recipient, uint256 amount, uint256 chainId);
    event LogSpellStakedReceived(uint16 srcChainId, uint32 timestamp, uint128 amount);
    event LogSetReporter(uint256 indexed chainIdLZ, bytes32 reporter);
    event LogSetParameters(address _sspellBuyback, address _treasury, uint256 _treasuryPercentage);

    error ErrNotNoon();
    error ErrNotPastNoon();
    error ErrNotUpdated(uint256);
    error ErrChainAlreadyAdded();
    error ErrInvalidReporter(bytes32);
    error ErrNotOftV2Proxy();

    /// @dev MSpell staking contracts
    struct MSpellRecipients {
        address recipient;
        uint32 chainId;
        uint32 chainIdLZ;
        uint32 lastUpdated;
        uint128 stakedAmount;
    }

    struct ChainInfo {
        bool active;
        uint32 recipientIndex;
    }

    struct DistributionTransfer {
        uint256 amount;
        address recipient;
        uint96 bridgeFee; // in native token when
    }

    struct DistributionInfoItem {
        uint32 chainId;
        uint32 chainIdLZ;
        DistributionTransfer[] transfers;
    }

    struct DistributionInfo {
        uint128 treasuryAllocation;
        uint128 amountToBeDistributed;
        uint256 totalSpellStaked;
        DistributionInfoItem[] items;
    }

    /// @dev addresses can be hardcoded as this contract will only live on mainnet
    ERC20 private constant MIM = ERC20(0x99D8a9C45b2ecA8864373A26D1459e3Dff1e17F3);
    ERC20 private constant SPELL = ERC20(0x090185f2135308BaD17527004364eBcC2D37e5F6);
    address private constant SSPELL = 0x26FA3fFFB6EfE8c1E69103aCb4044C26B9A106a9;
    address private constant LZ_ENDPOINT = 0x66A71Dcef29A0fFBDBE3c6a460a3B5BC225Cd675;
    ILzOFTV2 private constant LZ_OFVT2_PROXY = ILzOFTV2(0x439a5f0f5E8d149DDA9a0Ca367D4a8e4D6f83C10);
    uint256 private constant TREASURY_FEE_PRECISION = 100;

    uint256 private constant MSPELL_DISTRIBUTION_TRANSFER_INDEX = 0;
    uint256 private constant SSPELL_DISTRIBUTION_TRANSFER_INDEX = 1;

    address public sspellBuyBack = 0xDF2C270f610Dc35d8fFDA5B453E74db5471E126B;
    address public treasury = 0xDF2C270f610Dc35d8fFDA5B453E74db5471E126B;
    uint256 public treasuryPercentage = 25;

    MSpellRecipients[] public recipients;
    mapping(uint256 => ChainInfo) public chainInfo;
    mapping(uint256 => bytes32) public mSpellReporter;
    uint256 private lastDistributed;

    constructor(address _owner) OperatableV2(_owner) {
        MIM.approve(address(LZ_OFVT2_PROXY), type(uint256).max);
    }

    /// @notice Precompute the distribution of MIM rewards with every transfer and layerzero bridging fees when required.
    /// @dev Save gas when distributing since this can be called off-chain.
    /// DistributionInfo can then be used as-is in the distribute function.
    /// The gas estimation part can be ovverided by the caller if needed.
    /// It's up to the caller to make sure the distribution is valid when distribute function is called.
    function previewDistribution() external view returns (DistributionInfo memory distributionInfo) {
        // add 1 for mainnet since there's another transfer for sSPELL
        distributionInfo.items = new DistributionInfoItem[](recipients.length);

        distributionInfo.amountToBeDistributed = uint128(MIM.balanceOf(address(this)));
        distributionInfo.treasuryAllocation = uint128(
            (distributionInfo.amountToBeDistributed * treasuryPercentage) / TREASURY_FEE_PRECISION
        );
        distributionInfo.amountToBeDistributed -= distributionInfo.treasuryAllocation;

        // mainnet sSPELL & mSPELL staked amount
        uint256 mainnetSSpellStakedAmount;
        uint256 mainnetMSpellStakedAmount;

        /// @dev Calculate the total amount of staked SPELL on mSPELL and sSPELL
        for (uint256 i = 0; i < recipients.length; i++) {
            if (recipients[i].chainId == 1) {
                mainnetMSpellStakedAmount = SPELL.balanceOf(SSPELL);
                mainnetSSpellStakedAmount = SPELL.balanceOf(recipients[i].recipient);
                distributionInfo.totalSpellStaked += mainnetSSpellStakedAmount + mainnetMSpellStakedAmount;
            } else {
                distributionInfo.totalSpellStaked += recipients[i].stakedAmount;
            }
        }

        for (uint256 i = 0; i < recipients.length; i++) {
            distributionInfo.items[i].chainId = recipients[i].chainId;
            distributionInfo.items[i].chainIdLZ = recipients[i].chainIdLZ;

            // Mainnet distribution
            if (recipients[i].chainId == 1) {
                distributionInfo.items[i].transfers = new DistributionTransfer[](2);

                // MSpell distribution
                distributionInfo.items[i].transfers[MSPELL_DISTRIBUTION_TRANSFER_INDEX] = DistributionTransfer(
                    (distributionInfo.amountToBeDistributed * mainnetMSpellStakedAmount) / distributionInfo.totalSpellStaked,
                    recipients[i].recipient,
                    0
                );

                // SSpell distribution
                distributionInfo.items[i].transfers[SSPELL_DISTRIBUTION_TRANSFER_INDEX] = DistributionTransfer(
                    (distributionInfo.amountToBeDistributed * mainnetSSpellStakedAmount) / distributionInfo.totalSpellStaked,
                    sspellBuyBack,
                    0
                );
            }
            // Altchain distribution
            else {
                uint256 amount = (distributionInfo.amountToBeDistributed * recipients[i].stakedAmount) / distributionInfo.totalSpellStaked;

                if (amount > 0) {
                    // Pre-compute the estimated bridge fee for convenience
                    uint256 gas = ILzApp(address(LZ_OFVT2_PROXY)).minDstGasLookup(
                        uint16(recipients[i].chainIdLZ),
                        0 /* packet type for sendFrom */
                    );
                    bytes memory adapterParams = abi.encodePacked(uint16(1), gas);
                    bytes32 toAddress = bytes32(uint256(uint160(recipients[i].recipient)));
                    (uint fee, ) = LZ_OFVT2_PROXY.estimateSendFee(uint16(recipients[i].chainIdLZ), toAddress, amount, false, adapterParams);

                    distributionInfo.items[i].transfers = new DistributionTransfer[](1);
                    distributionInfo.items[i].transfers[0] = DistributionTransfer(amount, recipients[i].recipient, uint96(fee));
                }
            }
        }
    }

    /// @notice Distribute MIM rewards to stakers
    /// previewDistribution can be used to precompute the distribution and estimate the gas cost
    /// The operator should make sure all the recipients lastUpdated are up to date.
    /// Every altchains should have sent their cauldron's fees and notified their stakedAmounts
    function distribute(DistributionInfo calldata distributionInfo) external onlyOperators {
        MIM.transfer(treasury, distributionInfo.treasuryAllocation);

        for (uint256 i = 0; i < distributionInfo.items.length; i++) {
            DistributionInfoItem memory item = distributionInfo.items[i];

            // Mainnet distribution
            if (item.chainId == 1) {
                MIM.transfer(
                    item.transfers[MSPELL_DISTRIBUTION_TRANSFER_INDEX].recipient,
                    item.transfers[MSPELL_DISTRIBUTION_TRANSFER_INDEX].amount
                );
                MIM.transfer(
                    item.transfers[SSPELL_DISTRIBUTION_TRANSFER_INDEX].recipient,
                    item.transfers[SSPELL_DISTRIBUTION_TRANSFER_INDEX].amount
                );
            }
            // Altchain distribution
            else {
                uint256 amount = item.transfers[0].amount;
                address recipient = item.transfers[0].recipient;

                if (amount > 0) {
                    ILzCommonOFT.LzCallParams memory params = ILzCommonOFT.LzCallParams({
                        refundAddress: payable(address(this)),
                        zroPaymentAddress: address(0),
                        adapterParams: abi.encodePacked(uint16(1), uint256(item.transfers[0].bridgeFee))
                    });

                    LZ_OFVT2_PROXY.sendFrom{value: item.transfers[0].bridgeFee}(
                        address(this),
                        uint16(item.chainIdLZ),
                        bytes32(uint256(uint160(item.transfers[0].recipient))),
                        amount,
                        params
                    );

                    emit LogBridgeToRecipient(recipient, amount, item.chainId);
                }
            }
        }

        lastDistributed = block.timestamp;
    }

    /**
     * @dev Receive the MIM rewards from an alt chain and store the amount staked.
     * @param _srcChainId The chain id of the source chain.
     * @param _payload encoding source chain mSpell staked amount.
     */
    function onOFTReceived(uint16 _srcChainId, bytes calldata, uint64, bytes32 from, uint, bytes calldata _payload) external {
        // only need to check that the sender is the OFT proxy as it's
        // already making sure the OFT sender is a trusted remote in LzApp
        if (msg.sender != address(LZ_OFVT2_PROXY)) {
            revert ErrNotOftV2Proxy();
        }
        if (mSpellReporter[uint256(_srcChainId)] != from) {
            revert ErrInvalidReporter(from);
        }

        uint256 recipientIndex = chainInfo[uint256(_srcChainId)].recipientIndex;
        MSpellRecipients storage recipient = recipients[recipientIndex];
        recipient.stakedAmount = abi.decode(_payload, (uint128));
        recipient.lastUpdated = uint32(block.timestamp);
        emit LogSpellStakedReceived(_srcChainId, uint32(block.timestamp), recipient.stakedAmount);
    }

    function addMSpellRecipient(address recipient, uint256 chainId, uint256 lzChainId) external onlyOwner {
        if (chainInfo[chainId].active) {
            revert ErrChainAlreadyAdded();
        }

        uint256 position = recipients.length;
        chainInfo[lzChainId] = ChainInfo({active: true, recipientIndex: uint32(position)});
        recipients.push(MSpellRecipients(recipient, uint32(chainId), uint32(lzChainId), 0, 0));
        emit LogAddRecipient(recipient, chainId, lzChainId);
    }

    function addReporter(bytes32 reporter, uint256 lzChainId) external onlyOwner {
        mSpellReporter[lzChainId] = reporter;
        emit LogSetReporter(lzChainId, reporter);
    }

    function setParameters(address _sspellBuyBack, address _treasury, uint256 _treasuryPercentage) external onlyOwner {
        sspellBuyBack = _sspellBuyBack;
        treasury = _treasury;
        treasuryPercentage = _treasuryPercentage;
        emit LogSetParameters(_sspellBuyBack, _treasury, _treasuryPercentage);
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
