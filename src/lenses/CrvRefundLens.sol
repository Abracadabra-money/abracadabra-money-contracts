// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "BoringSolidity/ERC20.sol";
import "interfaces/ICauldronV4.sol";
import "interfaces/IMarketLens.sol";
import "interfaces/IGaugeController.sol";
import "interfaces/IVoteEscrowedCrv.sol";
import "interfaces/IYBribeV3.sol";
import "interfaces/IBentoBoxV1.sol";

import "forge-std/console2.sol";

contract CrvRefundLens {
    address private constant SPELL_ADDR = 0x090185f2135308BaD17527004364eBcC2D37e5F6;
    address private constant LENS_ADDR = 0x73F52bD9e59EdbDf5Cf0DD59126Cef00ecC31528;
    address private constant CRV_CAULDRON_ADDR = 0x207763511da879a900973A5E092382117C3c1588;
    address private constant CRV_CAULDRON_2_ADDR = 0x7d8dF3E4D06B0e19960c19Ee673c0823BEB90815;
    address private constant YBRIBE_V2_ADDR = 0x7893bbb46613d7a4FbcC31Dab4C9b823FfeE1026;
    address private constant YBRIBE_V3_ADDR = 0x03dFdBcD4056E2F92251c7B07423E1a33a7D3F6d;
    address private constant CURVE_MIM_GAUGE_ADDR = 0xd8b712d29381748dB89c36BCa0138d7c75866ddF;
    address private constant CURVE_GAUGE_CONTROLLER_ADDR = 0x2F50D538606Fa9EDD2B11E2446BEb18C9D5846bB;
    address private constant SPELL_ORACLE_ADDR = 0x75e14253dE6a5c2af12d5f1a1EA0A2E11e69EC10;
    address private constant VE_CRV_ADDR = 0x5f3b5DfEb7B28CDbD7FAba78963EE202a494e2A2;
    address private constant DEGENBOX = 0xd96f48665a1410C0cd669A88898ecA36B9Fc2cce;
    address private constant FEE_WITHDRAWER = 0x9cC903e42d3B14981C2109905556207C6527D482;
    ERC20 private constant MIM = ERC20(0x99D8a9C45b2ecA8864373A26D1459e3Dff1e17F3);

    uint256 constant WEEKS_IN_YEAR = 52;
    IMarketLens private immutable marketLens;
    IGaugeController private immutable gaugeController;
    IVoteEscrowedCrv private immutable voteEscrowedCrv;
    IYBribeV3 private immutable yBribeContract;

    struct AmountValue {
        uint256 amount;
        uint256 value;
    }

    struct RefundInfo {
        address[] cauldrons;
        uint256 spellPrice;
        uint256[] userBorrowAmounts;
        uint256 userVeCrvVoted;
        uint256 userBribesReceived;
    }
    uint256 constant PRECISION = 1e18;
    uint256 constant TENK_PRECISION = 1e5;
    uint256 constant BPS_PRECISION = 1e4;

    constructor() {
        marketLens = IMarketLens(LENS_ADDR);
        gaugeController = IGaugeController(CURVE_GAUGE_CONTROLLER_ADDR);
        voteEscrowedCrv = IVoteEscrowedCrv(VE_CRV_ADDR);
        yBribeContract = IYBribeV3(YBRIBE_V3_ADDR);
    }

    function getUserBorrowAmounts(ICauldronV4[] calldata cauldrons, address user) public view returns (uint256[] memory borrows) {
        borrows = new uint256[](cauldrons.length);
        for (uint256 i = 0; i < cauldrons.length; i++) {
            borrows[i] = marketLens.getUserBorrow(address(cauldrons[i]), user);
        }
    }

    function getVoterMimGaugeVotes(address votingAddress) public view returns (uint256) {
        uint256 voterVeCrv = getVoterVeCrv(votingAddress);
        uint256 mimGaugePower = getVoterMimGaugePower(votingAddress);
        return (voterVeCrv * mimGaugePower) / 1e4;
    }

    function getVoterVeCrv(address votingAddress) public view returns (uint256) {
        return voteEscrowedCrv.balanceOf(votingAddress);
    }

    // Get MIM gauge power of a voter. Power represents % of veCrv balance applied to gauge.
    function getVoterMimGaugePower(address votingAddress) public view returns (uint256) {
        (, uint256 power, ) = gaugeController.vote_user_slopes(votingAddress, CURVE_MIM_GAUGE_ADDR);
        return power;
    }

    function getSpellPrice() public view returns (uint256) {
        IOracle oracle = IOracle(SPELL_ORACLE_ADDR);
        bytes memory data = abi.encodePacked(uint256(0));
        return PRECISION ** 2 / oracle.peekSpot(data);
    }

    function getTotalMimGaugeVotes() public view returns (uint256) {
        return gaugeController.get_gauge_weight(CURVE_MIM_GAUGE_ADDR);
    }

    function getWeeklySpellBribes() public view returns (uint256) {
        uint256 rewardsPerGauge = yBribeContract.reward_per_gauge(CURVE_MIM_GAUGE_ADDR, SPELL_ADDR);
        uint256 claimsPerGauge = yBribeContract.claims_per_gauge(CURVE_MIM_GAUGE_ADDR, SPELL_ADDR);
        return rewardsPerGauge - claimsPerGauge;
    }

    function getVoterSpellBribes(address votingAddress) public view returns (uint256) {
        uint256 totalMimGaugeVotes = getTotalMimGaugeVotes();
        uint256 voterMimGaugeVotes = getVoterMimGaugeVotes(votingAddress);
        uint256 weeklySpellBribes = getWeeklySpellBribes();

        // Pro-rate total SPELL bribes by voter's share of gauge votes
        return (weeklySpellBribes * voterMimGaugeVotes) / totalMimGaugeVotes;
    }

    function getVoterSpellBribesUsd(address votingAddress) public view returns (uint256) {
        return (getVoterSpellBribes(votingAddress) * getSpellPrice()) / PRECISION;
    }

    function getRefundInfo(ICauldronV4[] calldata cauldrons, address user, address votingAddress) public view returns (RefundInfo memory) {
        address[] memory cauldronContracts = new address[](cauldrons.length);
        for (uint256 i = 0; i < cauldrons.length; i++) {
            cauldronContracts[i] = address(cauldrons[i]);
        }

        return
            RefundInfo({
                cauldrons: cauldronContracts,
                spellPrice: getSpellPrice(),
                userBorrowAmounts: getUserBorrowAmounts(cauldrons, user),
                userVeCrvVoted: getVoterMimGaugeVotes(votingAddress),
                userBribesReceived: getVoterSpellBribesUsd(votingAddress)
            });
    }

    function handleFees(ICauldronV4[] calldata cauldrons, uint128 refund) external returns (uint128 totalFeesWithdrawn) {
        totalFeesWithdrawn = 0;

        for (uint256 i = 0; i < cauldrons.length; i++) {
            ICauldronV4 cauldron = cauldrons[i];

            Rebase memory totalBorrow = cauldron.totalBorrow();
            (uint64 lastAccrued, uint128 feesEarned, uint64 INTEREST_PER_SECOND) = cauldron.accrueInfo();
            uint256 elapsedTime = block.timestamp - lastAccrued;

            console2.log("block.timestamp", block.timestamp);
            console2.log("lastAccrued", lastAccrued);
            console2.log("totalBorrow.elastic", totalBorrow.elastic);
            console2.log("feesEarned", feesEarned);
            console2.log("IPS", INTEREST_PER_SECOND);

            if (elapsedTime != 0 && totalBorrow.base != 0) {
                totalFeesWithdrawn += feesEarned + uint128((uint256(totalBorrow.elastic) * INTEREST_PER_SECOND * elapsedTime) / 1e18);
                cauldron.withdrawFees();
            }
        }

        if (totalFeesWithdrawn > refund) {
            // IBentoBoxV1(DEGENBOX).withdraw(MIM, msg.sender, msg.sender, 0, totalFeesWithdrawn);
            // MIM.transfer(FEE_WITHDRAWER, totalFeesWithdrawn - refund);
        }
    }
}
