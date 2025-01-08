// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import {BoringOwnable} from "@BoringSolidity/BoringOwnable.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {OwnableRoles} from "@solady/auth/OwnableRoles.sol";
import {OwnableOperators} from "/mixins/OwnableOperators.sol";
import {ILzApp, ILzOFTV2, ILzCommonOFT} from "@abracadabra-oftv2/interfaces/ILayerZero.sol";
import {LayerZeroLib} from "../utils/LayerZeroLib.sol";
import {IBentoBoxLite} from "/interfaces/IBentoBoxV1.sol";
import {CauldronFeeWithdrawerScript} from "script/CauldronFeeWithdrawer.s.sol";
import {CauldronFeeWithdrawer} from "/periphery/CauldronFeeWithdrawer.sol";
import {ICauldronV1} from "/interfaces/ICauldronV1.sol";
import {IMultiRewardsStaking} from "/interfaces/IMultiRewardsStaking.sol";
import {CauldronInfo as CauldronRegistryInfo} from "/periphery/CauldronRegistry.sol";

contract CauldronFeeWithdrawerTest is BaseTest {
    using SafeTransferLib for address;

    event LogRewardAdded(uint256 reward);
    event LogMimTotalWithdrawn(uint256 amount);

    CauldronFeeWithdrawer withdrawer;
    address mim;
    ILzOFTV2 oft;

    address constant ARBITRUM_MIM_WHALE = 0x27807dD7ADF218e1f4d885d54eD51C70eFb9dE50;
    uint256 constant ARBITRUM_FORK_BLOCK = 292945832;
    uint256 constant MAINNET_FORK_BLOCK = 21572978;

    function _setup(
        uint256 chainId,
        uint256 forkBlock
    ) internal returns (CauldronFeeWithdrawer _withdrawer, CauldronRegistryInfo[] memory _cauldronInfos) {
        fork(chainId, forkBlock);
        super.setUp();

        CauldronFeeWithdrawerScript script = new CauldronFeeWithdrawerScript();
        script.setTesting(true);
        _withdrawer = script.deploy();

        mim = _withdrawer.mim();
        oft = _withdrawer.oft();

        uint256 cauldronCount = _withdrawer.cauldronInfosCount();

        pushPrank(_withdrawer.mimProvider());
        mim.safeApprove(address(_withdrawer), type(uint256).max);
        popPrank();

        _cauldronInfos = new CauldronRegistryInfo[](cauldronCount);

        for (uint256 i = 0; i < cauldronCount; i++) {
            CauldronRegistryInfo memory cauldronInfo = _withdrawer.registry().get(i);
            ICauldronV1 masterContract = ICauldronV1(cauldronInfo.cauldron).masterContract();
            address owner = BoringOwnable(address(masterContract)).owner();

            vm.prank(owner);
            masterContract.setFeeTo(address(_withdrawer));

            _cauldronInfos[i] = cauldronInfo;
        }
    }

    function _cauldronPredicate(address, CauldronStatus status, uint8, string memory, uint256 creationBlock) external pure returns (bool) {
        return creationBlock <= ARBITRUM_FORK_BLOCK && status != CauldronStatus.Removed;
    }

    function testWithdraw() public {
        CauldronRegistryInfo[] memory allCauldrons;
        (withdrawer, allCauldrons) = _setup(ChainId.Arbitrum, ARBITRUM_FORK_BLOCK);

        // deposit fund into each registered bentoboxes
        vm.startPrank(ARBITRUM_MIM_WHALE);
        uint256 cauldronCount = withdrawer.cauldronInfosCount();

        assertGt(cauldronCount, 0, "No cauldron registered");

        uint256 totalFeeEarned;
        uint256 mimBefore = mim.balanceOf(address(withdrawer));

        for (uint256 i = 0; i < cauldronCount; i++) {
            CauldronRegistryInfo memory cauldronInfo = withdrawer.registry().get(i);
            uint256 feeEarned;

            ICauldronV1(cauldronInfo.cauldron).accrue();

            if (cauldronInfo.version == 1) {
                (, feeEarned) = ICauldronV1(cauldronInfo.cauldron).accrueInfo();
            } else if (cauldronInfo.version >= 2) {
                (, feeEarned, ) = ICauldronV2(cauldronInfo.cauldron).accrueInfo();
            }

            totalFeeEarned += feeEarned;
        }

        assertGt(totalFeeEarned, 0, "No fee earned");

        vm.expectEmit(false, false, false, false);
        emit LogMimTotalWithdrawn(0);

        pushPrank(withdrawer.owner());
        withdrawer.withdraw(allCauldrons);
        popPrank();

        uint256 mimAfter = mim.balanceOf(address(withdrawer));
        assertGe(mimAfter, mimBefore, "MIM balance should increase");
        assertApproxEqAbs(mimAfter - mimBefore, totalFeeEarned, 1e2, "MIM balance should increase by at least totalFeeEarned");
    }

    function testWithdrawOnlyFromSpecificCauldrons() public {
        (withdrawer, ) = _setup(ChainId.Arbitrum, ARBITRUM_FORK_BLOCK);

        CauldronRegistryInfo[] memory cauldronInfos = new CauldronRegistryInfo[](2);
        cauldronInfos[0] = withdrawer.registry().get(0);
        cauldronInfos[1] = withdrawer.registry().get(4);

        ICauldronV1(cauldronInfos[0].cauldron).accrue();
        (, uint256 feeEarned1, ) = ICauldronV2(cauldronInfos[0].cauldron).accrueInfo();

        ICauldronV1(cauldronInfos[1].cauldron).accrue();
        (, uint256 feeEarned2, ) = ICauldronV2(cauldronInfos[1].cauldron).accrueInfo();

        uint256 totalFeeEarned = feeEarned1 + feeEarned2;
        uint256 mimBefore = mim.balanceOf(address(withdrawer));

        pushPrank(withdrawer.owner());
        withdrawer.withdraw(cauldronInfos);
        popPrank();
        uint256 mimAfter = mim.balanceOf(address(withdrawer));

        assertApproxEqAbs(mimAfter - mimBefore, totalFeeEarned, 1, "MIM balance should increase by totalFeeEarned");
    }

    function testSetMimProvider() public {
        CauldronRegistryInfo[] memory allCauldrons;
        (withdrawer, allCauldrons) = _setup(ChainId.Arbitrum, ARBITRUM_FORK_BLOCK);

        vm.startPrank(withdrawer.owner());

        address newMimProvider = address(0x123);

        withdrawer.setMimProvider(newMimProvider);
        assertEq(newMimProvider, withdrawer.mimProvider());

        vm.stopPrank();
    }

    function testBridging() public {
        CauldronRegistryInfo[] memory allMainnetCauldrons;
        (withdrawer, allMainnetCauldrons) = _setup(ChainId.Mainnet, MAINNET_FORK_BLOCK);

        uint256 amount = mim.balanceOf(address(withdrawer));
        assertEq(amount, 0, "MIM balance should be 0");

        uint256 amountToBridge = 1 ether;
        pushPrank(withdrawer.owner());
        withdrawer.withdraw(allMainnetCauldrons);

        amount = mim.balanceOf(address(withdrawer));
        assertGt(amount, 0, "MIM balance should be greater than 0");

        // bridge 1e18 up to max available amount
        amountToBridge = bound(amountToBridge, 1e18, amount);

        (uint256 fee, uint256 gas) = withdrawer.estimateBridgingFee(amountToBridge);
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
        CauldronRegistryInfo[] memory allArbitrumCauldrons;
        (withdrawer, allArbitrumCauldrons) = _setup(ChainId.Arbitrum, ARBITRUM_FORK_BLOCK);

        pushPrank(toolkit.getAddress("LZendpoint"));
        uint256 mimBefore = mim.balanceOf(address(withdrawer));
        assertEq(mimBefore, 0, "Arbitrum withdrawer MIM balance should be 0");

        pushPrank(withdrawer.owner());
        withdrawer.withdraw(allArbitrumCauldrons);
        popPrank();

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

        address staking = toolkit.getAddress("bSpell.staking");
        pushPrank(OwnableRoles(staking).owner());
        OwnableRoles(staking).grantRoles(address(withdrawer), IMultiRewardsStaking(staking).ROLE_REWARD_DISTRIBUTOR());
        popPrank();

        // Distribute 1 eth staking rewards
        pushPrank(withdrawer.owner());
        withdrawer.setStaking(staking);

        amount = mim.balanceOf(address(withdrawer));

        // acount for 50% fee amount
        uint256 userAmount = amountToBridge / 2;
        uint256 feeAmount = amountToBridge - userAmount;

        uint256 treasuryMimAmountBefore = mim.balanceOf(toolkit.getAddress("safe.yields"));

        vm.expectEmit(true, true, true, true);
        emit LogRewardAdded(userAmount);
        withdrawer.distribute(amountToBridge);
        popPrank();

        uint256 treasuryMimAmountAfter = mim.balanceOf(toolkit.getAddress("safe.yields"));
        assertEq(treasuryMimAmountAfter - treasuryMimAmountBefore, feeAmount, "Treasury MIM amount should be equal to fee amount");

        // check mim balance is before less 1 eth
        assertEq(amount - mim.balanceOf(address(withdrawer)), amountToBridge, "MIM amount should be 1");
    }
}
