// SPDX-License-Identifier: MIT
/// solhint-disable not-rely-on-time
pragma solidity >=0.8.0;

import "BoringSolidity/ERC20.sol";
import "BoringSolidity/libraries/BoringERC20.sol";
import "mixins/OperatableV2.sol";
import "interfaces/ILzReceiver.sol";
import "interfaces/IMSpell.sol";
import "interfaces/ILzOFTV2.sol";
import "interfaces/ILzOFTReceiverV2.sol";
import "forge-std/console2.sol";

/// @notice Responsible of sending MIM rewards to MSpell staking and sSPELL buyback contract.
/// Mainnet Only
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

    ERC20 private constant MIM = ERC20(0x99D8a9C45b2ecA8864373A26D1459e3Dff1e17F3);
    ERC20 private constant SPELL = ERC20(0x090185f2135308BaD17527004364eBcC2D37e5F6);
    address private constant SSPELL = 0x26FA3fFFB6EfE8c1E69103aCb4044C26B9A106a9;
    address private constant LZ_ENDPOINT = 0x66A71Dcef29A0fFBDBE3c6a460a3B5BC225Cd675;
    ILzOFTV2 private constant LZ_OFVT2_PROXY = ILzOFTV2(0x439a5f0f5E8d149DDA9a0Ca367D4a8e4D6f83C10);
    uint256 private constant TREASURY_FEE_PRECISION = 100;

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

    // TODO: extract to gelato web3-function
    /*function isReadyForDistribution() external view returns (bool) {
        uint256 currentDay = BokkyPooBahsDateTimeLibrary.getDay(block.timestamp);

        if ((block.timestamp / 1 hours) % 24 != 13) {
            return false;
        }

        if (MIM.balanceOf(address(withdrawer)) < 100 ether) {
            return false;
        }

        uint256 length = recipients.length;
        for (uint256 i = 0; i < length; i++) {
            if (recipients[i].chainId != 1) {
                if (BokkyPooBahsDateTimeLibrary.getDay(uint256(recipients[i].lastUpdated)) != currentDay) {
                    return false;
                }
            }
        }

        return true;
    }*/

    /*
        TODO: extract to gelato web3-function 
        modifier onlyPastNoon() {
            uint256 hour = (block.timestamp / 1 hours) % 24;
            if (hour != 13) {
                revert ErrNotPastNoon();
            }
            _;
        }
    */
    function distribute() external onlyOperators {
        uint256 totalSpellStaked;
        uint256 amountToBeDistributed = MIM.balanceOf(address(this));
        uint256 treasuryAllocation = (amountToBeDistributed * treasuryPercentage) / TREASURY_FEE_PRECISION;

        // distribute treasury allocation
        MIM.transfer(treasury, treasuryAllocation);
        amountToBeDistributed -= treasuryAllocation;

        uint256 sspellAmount = SPELL.balanceOf(SSPELL);
        uint256 mspellAmount;
        uint256 length = recipients.length;

        /// @dev Calculate the total amount of staked SPELL on mSPELL and sSPELL
        for (uint256 i = 0; i < length; i++) {
            if (recipients[i].chainId == 1) {
                mspellAmount = SPELL.balanceOf(recipients[i].recipient);
                totalSpellStaked += mspellAmount + sspellAmount;
            } else {
                totalSpellStaked += recipients[i].stakedAmount;
            }
        }

        for (uint256 i = 0; i < length; i++) {
            // Mainnet distribution
            if (recipients[i].chainId == 1) {
                uint256 amountMSpell = (amountToBeDistributed * mspellAmount) / totalSpellStaked;
                uint256 amountsSpell = (amountToBeDistributed * sspellAmount) / totalSpellStaked;

                MIM.transfer(recipients[i].recipient, amountMSpell);
                IMSpell(recipients[i].recipient).updateReward();
                MIM.transfer(sspellBuyBack, amountsSpell);
            }
            // Altchain distribution
            else {
                uint256 amount = (amountToBeDistributed * recipients[i].stakedAmount) / totalSpellStaked;
                if (amount > 0) {
                    //ANYSWAP_ROUTER.anySwapOutUnderlying(ANY_MIM, recipients[i].recipient, amount, recipients[i].chainId);
                    emit LogBridgeToRecipient(recipients[i].recipient, amount, recipients[i].chainId);
                }
            }
        }

        lastDistributed = block.timestamp;
    }

    /**
     * @dev Receive the MIM rewards from an alt chain and store the amount staked.
     * @param _srcChainId The chain id of the source chain.
     * @param _srcAddress The address of the OFT token contract on the source chain.
     * @param _payload encoding source chain mSpell staked amount.
     */

    /*
        TODO: extract to gelato web3-function
        modifier onlyNoon() {
            uint256 hour = (block.timestamp / 1 hours) % 24;
            if (hour != 12) {
                revert ErrNotNoon();
            }
            _;
        }
    */
    function onOFTReceived(uint16 _srcChainId, bytes calldata _srcAddress, uint64, bytes32 from, uint, bytes calldata _payload) external {
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
