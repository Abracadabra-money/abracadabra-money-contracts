// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import {BoringOwnable} from "@BoringSolidity/BoringOwnable.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {ILzApp, ILzOFTV2, ILzCommonOFT} from "@abracadabra-oftv2/interfaces/ILayerZero.sol";
import {LayerZeroLib} from "../utils/LayerZeroLib.sol";
import {IBentoBoxLite} from "/interfaces/IBentoBoxV1.sol";
import {CauldronFeeWithdrawerScript} from "script/CauldronFeeWithdrawer.s.sol";
import {CauldronFeeWithdrawer} from "/periphery/CauldronFeeWithdrawer.sol";
import {ICauldronV1} from "/interfaces/ICauldronV1.sol";

contract CauldronFeeWithdrawerTest is BaseTest {
    using SafeTransferLib for address;

    event LogMimTotalWithdrawn(uint256 amount);

    CauldronFeeWithdrawer withdrawer;
    address mim;
    ILzOFTV2 oft;

    address constant MIM_WHALE = 0x27807dD7ADF218e1f4d885d54eD51C70eFb9dE50;
    uint256 constant FORK_BLOCK = 292776537;

    function setUp() public override {
        fork(ChainId.Arbitrum, FORK_BLOCK);
        super.setUp();

        CauldronFeeWithdrawerScript script = new CauldronFeeWithdrawerScript();
        script.setTesting(true);
        withdrawer = script.deploy();

        mim = withdrawer.mim();
        oft = withdrawer.oft();

        pushPrank(withdrawer.owner());
        CauldronInfo[] memory cauldronInfos = toolkit.getCauldrons(block.chainid, this._cauldronPredicate);
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

    function _cauldronPredicate(address, CauldronStatus status, uint8, string memory, uint256 creationBlock) external pure returns (bool) {
        return creationBlock <= FORK_BLOCK && status != CauldronStatus.Removed;
    }

    function testWithdraw() public {
        // deposit fund into each registered bentoboxes
        vm.startPrank(MIM_WHALE);
        uint256 cauldronCount = withdrawer.cauldronInfosCount();

        assertGt(cauldronCount, 0, "No cauldron registered");

        uint256 totalFeeEarned;
        uint256 mimBefore = mim.balanceOf(address(withdrawer));

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
        emit LogMimTotalWithdrawn(0);
        withdrawer.withdraw();

        uint256 mimAfter = mim.balanceOf(address(withdrawer));
        assertGe(mimAfter, mimBefore, "MIM balance should increase");
        assertApproxEqAbs(mimAfter - mimBefore, totalFeeEarned, 1e2, "MIM balance should increase by at least totalFeeEarned");

        console2.log("totalFeeEarned", mimAfter - mimBefore);
    }

    function testSetMimProvider() public {
        vm.startPrank(withdrawer.owner());

        address newMimProvider = address(0x123);

        withdrawer.setMimProvider(newMimProvider);
        assertEq(newMimProvider, withdrawer.mimProvider());

        vm.stopPrank();
    }

    function testEnableDisableCauldrons() public {
        uint256 count = withdrawer.cauldronInfosCount();
        assertGt(count, 0);

        if (count < 2) {
            vm.skip(true);
        }

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

    /*function testBridging() public {
        uint256 amountToBridge = 1 ether;

        vm.selectFork(forkId);
        pushPrank(withdrawer.owner());

        // update bridge recipient to mainnet distributor
        withdrawer.setParameters(withdrawer.mimProvider());
        withdrawer.withdraw();

        uint256 amount = mim.balanceOf(address(withdrawer));
        assertGt(amount, 0, "MIM balance should be greater than 0");

        // bridge 1e18 up to max available amount
        amountToBridge = bound(amountToBridge, 1e18, amount);

        (uint256 fee, uint256 gas) = withdrawer.estimateBridgingFee(amountToBridge);

        pushPrank(withdrawer.owner());
        vm.expectRevert(abi.encodeWithSignature("ErrNotEnoughNativeTokenToCoverFee()")); // no eth for gas fee
        withdrawer.bridge(amountToBridge, fee, gas);

        // send some eth to the withdrawer to cover bridging fees
        vm.deal(address(withdrawer), fee);
        withdrawer.bridge(amountToBridge, fee, gas);
        popPrank();

        ///////////////////////////////////////////////////////////////////////
        /// Hub (Arbitrum)
        ///////////////////////////////////////////////////////////////////////
        vm.selectFork(mainnetForkId);
        mim = IERC20(toolkit.getAddress(ChainId.Mainnet, "mim"));
        pushPrank(toolkit.getAddress("LZendpoint"));
        {
            uint256 mimBefore = mim.balanceOf(address(mainnetDistributor));
            ILzApp(toolkit.getAddress(ChainId.Mainnet, "mim.oftv2")).lzReceive(
                uint16(toolkit.getLzChainId(chainId)),
                abi.encodePacked(oft, toolkit.getAddress(ChainId.Mainnet, "mim.oftv2")),
                0, // not need for nonce here
                // (uint8 packetType, address to, uint64 amountSD, bytes32 from)
                abi.encodePacked(
                    LayerZeroLib.PT_SEND,
                    bytes32(uint256(uint160(address(mainnetDistributor)))),
                    LayerZeroLib.ld2sd(amountToBridge)
                )
            );
            assertEq(
                mim.balanceOf(address(mainnetDistributor)),
                mimBefore + (LayerZeroLib.sd2ld(LayerZeroLib.ld2sd(amountToBridge))),
                "mainnetDistributor should receive MIM"
            );
        }
        popPrank();
    }*/
}
