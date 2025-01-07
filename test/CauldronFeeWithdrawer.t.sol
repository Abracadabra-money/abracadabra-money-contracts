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

    address constant ARBITRUM_MIM_WHALE = 0x27807dD7ADF218e1f4d885d54eD51C70eFb9dE50;
    uint256 constant ARBITRUM_FORK_BLOCK = 292945832;
    uint256 constant MAINNET_FORK_BLOCK = 21572978;

    function _setup(uint256 chainId, uint256 forkBlock) internal returns (CauldronFeeWithdrawer _withdrawer) {
        fork(chainId, forkBlock);
        super.setUp();

        CauldronFeeWithdrawerScript script = new CauldronFeeWithdrawerScript();
        script.setTesting(true);
        _withdrawer = script.deploy();

        mim = _withdrawer.mim();
        oft = _withdrawer.oft();

        pushPrank(_withdrawer.owner());
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

        _withdrawer.setCauldrons(cauldrons, versions, enabled);
        popPrank();

        uint256 cauldronCount = _withdrawer.cauldronInfosCount();

        pushPrank(_withdrawer.mimProvider());
        mim.safeApprove(address(_withdrawer), type(uint256).max);
        popPrank();

        for (uint256 i = 0; i < cauldronCount; i++) {
            (, address masterContract, , ) = _withdrawer.cauldronInfos(i);
            address owner = BoringOwnable(masterContract).owner();
            vm.prank(owner);
            ICauldronV1(masterContract).setFeeTo(address(_withdrawer));
        }
    }

    function _cauldronPredicate(address, CauldronStatus status, uint8, string memory, uint256 creationBlock) external pure returns (bool) {
        return creationBlock <= ARBITRUM_FORK_BLOCK && status != CauldronStatus.Removed;
    }

    function testWithdraw() public {
        withdrawer = _setup(ChainId.Arbitrum, ARBITRUM_FORK_BLOCK);

        // deposit fund into each registered bentoboxes
        vm.startPrank(ARBITRUM_MIM_WHALE);
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
        withdrawer = _setup(ChainId.Arbitrum, ARBITRUM_FORK_BLOCK);

        vm.startPrank(withdrawer.owner());

        address newMimProvider = address(0x123);

        withdrawer.setMimProvider(newMimProvider);
        assertEq(newMimProvider, withdrawer.mimProvider());

        vm.stopPrank();
    }

    function testEnableDisableCauldrons() public {
        withdrawer = _setup(ChainId.Arbitrum, ARBITRUM_FORK_BLOCK);

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

    function testBridging() public {
        withdrawer = _setup(ChainId.Mainnet, MAINNET_FORK_BLOCK);

        uint256 amount = mim.balanceOf(address(withdrawer));
        assertEq(amount, 0, "MIM balance should be 0");

        uint256 amountToBridge = 1 ether;
        withdrawer.withdraw();

        amount = mim.balanceOf(address(withdrawer));
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

        // check mim balance is before less 1 eth
        assertEq(amount - mim.balanceOf(address(withdrawer)), 1e18, "MIM amount should be 1");
        popPrank();

        ///////////////////////////////////////////////////////////////////////
        /// Hub (Arbitrum)
        ///////////////////////////////////////////////////////////////////////

        withdrawer = _setup(ChainId.Arbitrum, ARBITRUM_FORK_BLOCK);

        pushPrank(toolkit.getAddress("LZendpoint"));
        uint256 mimBefore = mim.balanceOf(address(withdrawer));
        assertEq(mimBefore, 0, "Arbitrum withdrawer MIM balance should be 0");
        withdrawer.withdraw();
        mimBefore = mim.balanceOf(address(withdrawer));
        assertGt(mimBefore, 0, "MIM balance should be greater than 0");

        ILzApp(toolkit.getAddress("mim.oftv2")).lzReceive(
            uint16(toolkit.getLzChainId(ChainId.Mainnet)),
            abi.encodePacked(toolkit.getAddress(ChainId.Mainnet, "mim.oftv2"), toolkit.getAddress(ChainId.Arbitrum, "mim.oftv2")),
            0, // not need for nonce here
            // (uint8 packetType, address to, uint64 amountSD, bytes32 from)
            abi.encodePacked(LayerZeroLib.PT_SEND, bytes32(uint256(uint160(address(withdrawer)))), LayerZeroLib.ld2sd(amountToBridge))
        );

        assertEq(
            mim.balanceOf(address(withdrawer)),
            mimBefore + (LayerZeroLib.sd2ld(LayerZeroLib.ld2sd(amountToBridge))),
            "withdrawer should receive MIM"
        );
        popPrank();

uint previousStakingRewards = staking
        // Distribute 1 eth staking rewards
        pushPrank(withdrawer.owner());
        withdrawer.distribute(amountToBridge);
        popPrank();

        // check mim balance is before less 1 eth
        assertEq(amount - mim.balanceOf(address(withdrawer)), 1e18, "MIM amount should be 1");
    }
}
