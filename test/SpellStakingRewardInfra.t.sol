// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "BoringSolidity/BoringOwnable.sol";
import "libraries/SafeApprove.sol";
import "script/SpellStakingRewardInfra.s.sol";

/// @dev Common tests to mainnet and altchains
contract SpellStakingRewardInfraTestBase is BaseTest {
    using BoringERC20 for IERC20;
    using SafeApprove for IERC20;

    CauldronFeeWithdrawer withdrawer;
    SpellStakingRewardDistributor distributor;

    uint256 forkId;
    address oldWithdrawer;
    address mimWhale;
    IERC20 mim;
    uint256 chainId;
    ILzOFTV2 oft;
    uint128 mSpellStakedAmount;

    // cached here to avoid stack too deep
    bytes reporterPayload;

    function initialize(
        uint256 _chainId,
        uint256 blockNumber,
        address _mimWhale,
        address _oldWithdrawer
    ) public returns (SpellStakingRewardInfraScript script) {
        forkId = fork(_chainId, blockNumber);
        super.setUp();

        mimWhale = _mimWhale;
        oldWithdrawer = _oldWithdrawer;
        chainId = _chainId;
        mSpellStakedAmount = uint128(IERC20(constants.getAddress(chainId, "spell")).balanceOf(constants.getAddress(chainId, "mSpell")));
        assertGt(mSpellStakedAmount, 0, "mSpellStakedAmount should be greater than 0");

        script = new SpellStakingRewardInfraScript();
        script.setTesting(true);
    }

    function afterDeployed() public {
        mim = withdrawer.mim();
        oft = withdrawer.lzOftv2();
        reporterPayload = withdrawer.reporter().payload();

        pushPrank(withdrawer.owner());
        CauldronInfo[] memory cauldronInfos = constants.getCauldrons(block.chainid, true, this._cauldronPredicate);
        address[] memory cauldrons = new address[](cauldronInfos.length);
        uint8[] memory versions = new uint8[](cauldronInfos.length);
        bool[] memory enabled = new bool[](cauldronInfos.length);

        for (uint256 i = 0; i < cauldronInfos.length; i++) {
            CauldronInfo memory cauldronInfo = cauldronInfos[i];
            cauldrons[i] = cauldronInfo.cauldron;
            versions[i] = cauldronInfo.version;
            enabled[i] = true;
        }
        withdrawer.setCauldrons(cauldrons, versions, enabled);
        popPrank();

        uint256 cauldronCount = withdrawer.cauldronInfosCount();

        pushPrank(withdrawer.mimProvider());
        mim.safeApprove(address(withdrawer), type(uint256).max);
        popPrank();

        for (uint256 i = 0; i < cauldronCount; i++) {
            (, address masterContract, , ) = withdrawer.cauldronInfos(i);
            address owner = BoringOwnable(masterContract).owner();
            vm.prank(owner);
            ICauldronV1(masterContract).setFeeTo(address(withdrawer));
        }
    }

    function _cauldronPredicate(address, bool, uint8, string memory, uint256 creationBlock) external view returns (bool) {
        return creationBlock <= block.number;
    }

    function testWithdraw() public {
        // deposit fund into each registered bentoboxes
        vm.startPrank(mimWhale);
        address mimWithdrawRecipient = withdrawer.mimWithdrawRecipient();
        uint256 cauldronCount = withdrawer.cauldronInfosCount();

        assertGt(cauldronCount, 0, "No cauldron registered");

        uint256 totalFeeEarned;
        uint256 mimBefore = mim.balanceOf(address(mimWithdrawRecipient));

        for (uint256 i = 0; i < cauldronCount; i++) {
            (address cauldron, , , uint8 version) = withdrawer.cauldronInfos(i);
            uint256 feeEarned;

            ICauldronV1(cauldron).accrue();

            if (version == 1) {
                (, feeEarned) = ICauldronV1(cauldron).accrueInfo();
            } else if (version >= 2) {
                (, feeEarned, ) = ICauldronV2(cauldron).accrueInfo();
            }

            totalFeeEarned += feeEarned;
        }

        assertGt(totalFeeEarned, 0, "No fee earned");

        vm.expectEmit(false, false, false, false);
        emit CauldronFeeWithdrawWithdrawerEvents.LogMimTotalWithdrawn(0);
        withdrawer.withdraw();

        uint256 mimAfter = mim.balanceOf(address(mimWithdrawRecipient));
        assertGe(mimAfter, mimBefore, "MIM balance should increase");
        assertApproxEqAbs(mimAfter - mimBefore, totalFeeEarned, 1e1, "MIM balance should increase by at least totalFeeEarned");

        console2.log("totalFeeEarned", mimAfter - mimBefore);
    }

    function testParameters() public {
        vm.startPrank(withdrawer.owner());

        address newMimProvider = address(0x123);
        bytes32 newBridgeRecipient = bytes32(uint256(uint160(0x456)));
        address newMimWithdrawRecipient = address(0x789);
        address newReporter = address(0xabc);

        withdrawer.setParameters(newMimProvider, address(0x456), newMimWithdrawRecipient, ICauldronFeeWithdrawReporter(newReporter));
        assertEq(newMimProvider, withdrawer.mimProvider());
        assertEq(uint256(newBridgeRecipient), uint256(withdrawer.bridgeRecipient()));
        assertEq(newMimWithdrawRecipient, withdrawer.mimWithdrawRecipient());
        assertEq(newReporter, address(withdrawer.reporter()));

        vm.stopPrank();
    }

    function testEnableDisableCauldrons() public {
        uint256 count = withdrawer.cauldronInfosCount();
        assertGt(count, 0);

        address[] memory cauldrons = new address[](count);
        uint8[] memory versions = new uint8[](count);
        bool[] memory enabled = new bool[](count);

        (address cauldron1, , , ) = withdrawer.cauldronInfos(0);
        (address cauldron2, , , ) = withdrawer.cauldronInfos(1);
        for (uint256 i = 0; i < count; i++) {
            (address cauldron, , , uint8 version) = withdrawer.cauldronInfos(i);
            cauldrons[i] = cauldron;
            versions[i] = version;
            enabled[i] = false;
        }

        vm.startPrank(withdrawer.owner());
        withdrawer.setCauldrons(cauldrons, versions, enabled);

        count = withdrawer.cauldronInfosCount();
        assertEq(count, 0);

        withdrawer.withdraw();

        vm.expectRevert();
        withdrawer.setCauldron(alice, 2, true);

        withdrawer.setCauldron(cauldron1, 2, true);
        assertEq(withdrawer.cauldronInfosCount(), 1);
        withdrawer.setCauldron(cauldron1, 2, true);
        assertEq(withdrawer.cauldronInfosCount(), 1);
        withdrawer.setCauldron(cauldron1, 2, false);
        assertEq(withdrawer.cauldronInfosCount(), 0);

        withdrawer.setCauldron(cauldron1, 2, true);
        withdrawer.setCauldron(cauldron2, 2, true);
        assertEq(withdrawer.cauldronInfosCount(), 2);
        withdrawer.setCauldron(cauldron1, 2, false);
        withdrawer.setCauldron(cauldron2, 2, true);
        assertEq(withdrawer.cauldronInfosCount(), 1);
        withdrawer.setCauldron(cauldron2, 2, false);
        assertEq(withdrawer.cauldronInfosCount(), 0);
        vm.stopPrank();
    }

    function testOldFeeWithdrawerRewardMigration() public {
        CauldronFeeWithdrawer _oldWithdrawer = CauldronFeeWithdrawer(oldWithdrawer);
        uint256 oldWithdrawerMimBalance = mim.balanceOf(address(_oldWithdrawer));

        assertEq(mim.balanceOf(address(withdrawer)), 0, "New CauldronFeeWithdrawer should not have MIM balance");

        pushPrank(_oldWithdrawer.owner());
        // Fantom is still using MultichainWithdrawer
        if (block.chainid != ChainId.Fantom) {
            _oldWithdrawer.setOperator(_oldWithdrawer.owner(), true);
        }
        _oldWithdrawer.rescueTokens(mim, withdrawer.mimWithdrawRecipient(), mim.balanceOf(address(_oldWithdrawer)));
        popPrank();

        uint256 newBalance = mim.balanceOf(address(withdrawer));
        if (newBalance > 0) {
            console.log("Migrated %s MIM to new CauldronFeeWithdrawer", newBalance);
        }
        assertEq(newBalance, oldWithdrawerMimBalance, "New CauldronFeeWithdrawer should have the same MIM balance as the old one");
    }
}

/// @dev Common test for altchains
contract SpellStakingRewardInfraAltChainTestBase is SpellStakingRewardInfraTestBase {
    using BoringERC20 for IERC20;
    using SafeApprove for IERC20;

    /// forge-config: ci.fuzz.runs = 5000
    function testBridging(uint256 amountToBridge) public {
        ///////////////////////////////////////////////////////////////////////
        /// Mainnet
        ///////////////////////////////////////////////////////////////////////
        SpellStakingRewardDistributor mainnetDistributor;
        uint mainnetForkId = fork(ChainId.Mainnet, 17470779);
        {
            SpellStakingRewardInfraScript script = new SpellStakingRewardInfraScript();
            script.setTesting(true);
            (, mainnetDistributor) = script.deploy();
        }

        ///////////////////////////////////////////////////////////////////////
        // AltChain
        ///////////////////////////////////////////////////////////////////////
        vm.selectFork(forkId);
        pushPrank(withdrawer.owner());

        // update bridge recipient to mainnet distributor
        withdrawer.setParameters(
            withdrawer.mimProvider(),
            address(mainnetDistributor),
            withdrawer.mimWithdrawRecipient(),
            withdrawer.reporter()
        );

        assertNotEq(address(mainnetDistributor), address(0), "mainnetDistributor is zero");
        withdrawer.withdraw();

        uint256 amount = mim.balanceOf(address(withdrawer));
        assertGt(amount, 0, "MIM balance should be greater than 0");

        // bridge 1e18 up to max available amount
        amountToBridge = bound(amountToBridge, 1e18, amount);

        uint64 dstGasForCall = 100_000;
        (uint256 fee, bytes memory adapterParams) = withdrawer.estimateBridgingFee(amountToBridge, 0 /* use default min */, dstGasForCall);

        pushPrank(withdrawer.owner());
        vm.expectRevert(abi.encodeWithSignature("ErrNotEnoughNativeTokenToCoverFee()")); // no eth for gas fee
        withdrawer.bridge(amountToBridge, fee, dstGasForCall, adapterParams);

        // send some eth to the withdrawer to cover bridging fees
        vm.deal(address(withdrawer), fee);
        withdrawer.bridge(amountToBridge, fee, dstGasForCall, adapterParams);
        popPrank();

        ///////////////////////////////////////////////////////////////////////
        /// Mainnet
        ///////////////////////////////////////////////////////////////////////
        vm.selectFork(mainnetForkId);
        mim = IERC20(constants.getAddress(ChainId.Mainnet, "mim"));
        pushPrank(constants.getAddress("LZendpoint", ChainId.Mainnet));
        {
            (, uint32 recipientIndex) = mainnetDistributor.chainInfo(constants.getLzChainId(chainId));
            (, , , uint32 lastUpdated, uint128 stakedAmount) = mainnetDistributor.recipients(recipientIndex);
            assertEq(lastUpdated, 0);
            assertEq(stakedAmount, 0);
        }
        {
            uint256 mimBefore = mim.balanceOf(address(mainnetDistributor));
            ILzApp(constants.getAddress(ChainId.Mainnet, "oftv2")).lzReceive(
                uint16(constants.getLzChainId(chainId)),
                abi.encodePacked(oft, constants.getAddress(ChainId.Mainnet, "oftv2")),
                0, // not need for nonce here
                // (uint8 packetType, address to, uint64 amountSD, bytes32 from, uint64 dstGasForCall, bytes memory payloadForCall)
                abi.encodePacked(
                    LayerZeroLib.PT_SEND_AND_CALL,
                    bytes32(uint256(uint160(address(mainnetDistributor)))),
                    LayerZeroLib.ld2sd(amountToBridge),
                    bytes32(uint256(uint160(address(withdrawer)))),
                    dstGasForCall,
                    reporterPayload
                )
            );
            assertEq(
                mim.balanceOf(address(mainnetDistributor)),
                mimBefore + (LayerZeroLib.sd2ld(LayerZeroLib.ld2sd(amountToBridge))),
                "mainnetDistributor should receive MIM"
            );

            // verify updated timestamp
            {
                (, uint32 recipientIndex) = mainnetDistributor.chainInfo(constants.getLzChainId(chainId));
                (, , , uint32 lastUpdated, uint128 stakedAmount) = mainnetDistributor.recipients(recipientIndex);
                assertEq(lastUpdated, uint32(block.timestamp), "mainnetDistributor should have updated timestamp");
                assertEq(stakedAmount, uint128(mSpellStakedAmount), "mainnetDistributor wrong staked amount reported");
            }
        }
        popPrank();
    }
}

///////////////////////////////////////////////////////////////////////////////////////
// Mainnet Tests
//
// Contracts:
// - CauldronFeeWithdrawer
// - SpellStakingRewardDistributor
//
// Receives MIMs from Cauldrons (Mainnet + AltChains) -> Bridge Rewards -> AltChains
///////////////////////////////////////////////////////////////////////////////////////

contract MainnetSpellStakingInfraTest is SpellStakingRewardInfraTestBase {
    function setUp() public override {
        SpellStakingRewardInfraScript script = super.initialize(
            ChainId.Mainnet,
            17470779,
            0x5f0DeE98360d8200b20812e174d139A1a633EDd2, // MimWhale
            0x9cC903e42d3B14981C2109905556207C6527D482 // CauldronFeeWithdrawer
        );
        (withdrawer, distributor) = script.deploy();
        super.afterDeployed();

        assertEq(withdrawer.mimWithdrawRecipient(), address(distributor));
    }

    function testSetBentoBox() public {
        vm.startPrank(withdrawer.owner());

        IBentoBoxV1 box = IBentoBoxV1(constants.getAddress("mainnet.degenBox"));
        withdrawer.setBentoBox(box, true);

        uint256 count = withdrawer.bentoBoxesCount();
        withdrawer.setBentoBox(box, false);
        withdrawer.setBentoBox(box, true);
        withdrawer.setBentoBox(box, true);

        assertEq(count, withdrawer.bentoBoxesCount());
        withdrawer.setBentoBox(box, false);
        assertEq(count - 1, withdrawer.bentoBoxesCount());
        vm.stopPrank();
    }
}

///////////////////////////////////////////////////////////////////////////////////////
// AltChain Tests
//
// Contracts:
// - CauldronFeeWithdrawer
//
// Bridge Fees and Report StakedAmount -> Mainnet
///////////////////////////////////////////////////////////////////////////////////////

contract AvalancheSpellStakingInfraTest is SpellStakingRewardInfraAltChainTestBase {
    function setUp() public override {
        SpellStakingRewardInfraScript script = super.initialize(
            ChainId.Avalanche,
            31275748,
            0xae64A325027C3C14Cf6abC7818aA3B9c07F5C799, // MimWhale
            0xA262F31626FDb74808B30c3c8ad30aFebDD20eE7 // CauldronFeeWithdrawer
        );
        (withdrawer, distributor) = script.deploy();
        super.afterDeployed();

        assertEq(withdrawer.mimWithdrawRecipient(), address(withdrawer));
    }
}

contract ArbitrumSpellStakingInfraTest is SpellStakingRewardInfraAltChainTestBase {
    function setUp() public override {
        SpellStakingRewardInfraScript script = super.initialize(
            ChainId.Arbitrum,
            100723897,
            0x27807dD7ADF218e1f4d885d54eD51C70eFb9dE50, // MimWhale
            0xcF4f8E9A113433046B990980ebce5c3fA883067f // CauldronFeeWithdrawer
        );
        (withdrawer, distributor) = script.deploy();
        super.afterDeployed();

        assertEq(withdrawer.mimWithdrawRecipient(), address(withdrawer));
    }
}

contract FantomSpellStakingInfraTest is SpellStakingRewardInfraAltChainTestBase {
    function setUp() public override {
        SpellStakingRewardInfraScript script = super.initialize(
            ChainId.Fantom,
            64037485,
            0x6f86e65b255c9111109d2D2325ca2dFc82456efc, // MimWhale
            0x7a3b799E929C9bef403976405D8908fa92080449 // Multichain Withdrawer
        );
        (withdrawer, distributor) = script.deploy();
        super.afterDeployed();

        assertEq(withdrawer.mimWithdrawRecipient(), address(withdrawer));
    }
}
