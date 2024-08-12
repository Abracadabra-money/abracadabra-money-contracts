// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {BaseTest} from "utils/BaseTest.sol";
import {CauldronReducer} from "/periphery/CauldronReducer.sol";
import {CauldronRegistry, CauldronInfo} from "/periphery/CauldronRegistry.sol";
import {CauldronOwner} from "/periphery/CauldronOwner.sol";
import {IBentoBoxV1} from "/interfaces/IBentoBoxV1.sol";
import {ICauldronV2} from "/interfaces/ICauldronV2.sol";
import {ERC20} from "@BoringSolidity/ERC20.sol";

contract CauldronReducerTest is BaseTest {
    CauldronReducer cauldronReducer;
    CauldronOwner cauldronOwner;
    CauldronRegistry cauldronRegistry;

    address cauldronReducerOwner;
    address cauldronReducerOperator;
    address cauldronOwnerOwner;
    address cauldronRegistryOwner;
    ERC20 mim;
    address bentoBox;

    function setUp() public override {
        super.setUp();

        cauldronReducerOwner = makeAddr("CauldronReducerOwner");
        cauldronReducerOperator = makeAddr("CauldronReducerOperator");
        cauldronOwnerOwner = makeAddr("CauldronOwnerOwner");
        cauldronRegistryOwner = makeAddr("CauldronRegistryOwner");
        mim = ERC20(makeAddr("MIM"));
        bentoBox = makeAddr("BentoBox");

        cauldronRegistry = new CauldronRegistry(cauldronRegistryOwner);
        cauldronOwner = new CauldronOwner(makeAddr("Treasury"), mim, cauldronOwnerOwner);
        cauldronReducer = new CauldronReducer(cauldronOwner, address(mim), cauldronReducerOwner);

        vm.prank(cauldronOwnerOwner);
        cauldronOwner.setRegistry(cauldronRegistry);
        vm.prank(cauldronReducerOwner);
        cauldronReducer.setOperator(cauldronReducerOperator, true);
    }

    function _setBalanceBentoBox(ICauldronV2 cauldron, uint256 balance) public {
        vm.mockCall(address(cauldron), abi.encodeCall(ICauldronV2.bentoBox, ()), abi.encode(bentoBox));
        vm.mockCall(bentoBox, abi.encodeCall(IBentoBoxV1.balanceOf, (mim, address(cauldron))), abi.encode(balance));
        vm.mockCall(bentoBox, abi.encodeCall(IBentoBoxV1.toAmount, (mim, balance, true)), abi.encode(balance));
        vm.mockCall(address(cauldronOwner), abi.encodeCall(cauldronOwner.reduceCompletely, (cauldron)), abi.encode());
    }

    struct CauldronInfoWithBalance {
        CauldronInfo cauldronInfo;
        uint256 balance;
    }

    function testFuzzReduceCompletely(CauldronInfoWithBalance[] calldata cauldronInfoWithBalances, uint256 maxBalance) public {
        vm.expectEmit();
        emit CauldronReducer.LogMaxBalanceChanged(maxBalance);
        vm.prank(cauldronReducerOwner);
        cauldronReducer.setMaxBalance(maxBalance);

        address firstIneligibleCauldron = address(0);

        ICauldronV2[] memory cauldrons = new ICauldronV2[](cauldronInfoWithBalances.length);
        CauldronInfo[] memory cauldronInfos = new CauldronInfo[](cauldronInfoWithBalances.length);

        for (uint256 i = 0; i < cauldronInfoWithBalances.length; ++i) {
            CauldronInfoWithBalance calldata cauldronInfoWithBalance = cauldronInfoWithBalances[i];
            CauldronInfo calldata cauldronInfo = cauldronInfoWithBalance.cauldronInfo;

            assumeAddressIsNot(cauldronInfo.cauldron, AddressType.ZeroAddress, AddressType.Precompile, AddressType.ForgeAddress);

            // Assume no duplicates
            for (uint256 j = i + 1; j < cauldronInfoWithBalances.length; ++j) {
                vm.assume(cauldronInfo.cauldron != cauldronInfoWithBalances[j].cauldronInfo.cauldron);
            }

            if (firstIneligibleCauldron == address(0) && (cauldronInfoWithBalance.balance <= maxBalance || !cauldronInfo.deprecated)) {
                firstIneligibleCauldron = cauldronInfo.cauldron;
            }

            _setBalanceBentoBox(ICauldronV2(cauldronInfo.cauldron), cauldronInfoWithBalance.balance);

            cauldrons[i] = ICauldronV2(cauldronInfo.cauldron);
            cauldronInfos[i] = cauldronInfo;
        }

        vm.prank(cauldronRegistryOwner);
        cauldronRegistry.add(cauldronInfos);

        if (firstIneligibleCauldron != address(0)) {
            vm.expectRevert(abi.encodeWithSelector(CauldronReducer.ErrCauldronNotEligibleForReduction.selector, (firstIneligibleCauldron)));
            vm.prank(cauldronReducerOperator);
            cauldronReducer.reduceCompletely(cauldrons);
        } else {
            for (uint256 i = 0; i < cauldrons.length; ++i) {
                vm.expectCall(address(cauldrons[i]), abi.encodeCall(ICauldronV2.bentoBox, ()), 1);
                vm.expectCall(bentoBox, abi.encodeCall(IBentoBoxV1.balanceOf, (mim, address(cauldrons[i]))), 1);
                vm.expectCall(bentoBox, abi.encodeCall(IBentoBoxV1.toAmount, (mim, cauldronInfoWithBalances[i].balance, true)));
                vm.expectCall(address(cauldronOwner), abi.encodeCall(cauldronOwner.reduceCompletely, (cauldrons[i])), 1);
            }

            vm.prank(cauldronReducerOperator);
            cauldronReducer.reduceCompletely(cauldrons);
        }
    }

    function testFuzzChecker(uint256 maxBalance) public {
        vm.assume(maxBalance != type(uint256).max);
        vm.assume(maxBalance != 0);

        vm.expectEmit();
        emit CauldronReducer.LogMaxBalanceChanged(maxBalance);
        vm.prank(cauldronReducerOwner);
        cauldronReducer.setMaxBalance(maxBalance);

        bool canExec;
        bytes memory execPayload;
        {
            ICauldronV2[] memory cauldronsToReduceSupply = new ICauldronV2[](0);
            (canExec, execPayload) = cauldronReducer.checker();
            assertFalse(canExec);
            assertEq(execPayload, abi.encodeCall(CauldronReducer.reduceCompletely, (cauldronsToReduceSupply)));
        }

        address notDeprecated = makeAddr("NotDeprecatedCauldron");
        address zeroBalanceCauldron = makeAddr("ZeroBalanceCauldron");
        _setBalanceBentoBox(ICauldronV2(zeroBalanceCauldron), 0);
        address maxBalanceCauldron = makeAddr("MaxBalanceCauldron");
        _setBalanceBentoBox(ICauldronV2(maxBalanceCauldron), maxBalance);
        address aboveMaxBalanceCauldron = makeAddr("AboveMaxBalanceCauldron");
        _setBalanceBentoBox(ICauldronV2(aboveMaxBalanceCauldron), maxBalance + 1);

        {
            ICauldronV2[] memory cauldronsToReduceSupply = new ICauldronV2[](1);
            cauldronsToReduceSupply[0] = ICauldronV2(aboveMaxBalanceCauldron);

            CauldronInfo[] memory cauldronInfos = new CauldronInfo[](4);
            cauldronInfos[0] = CauldronInfo({cauldron: notDeprecated, version: 3, deprecated: false});
            cauldronInfos[1] = CauldronInfo({cauldron: zeroBalanceCauldron, version: 3, deprecated: true});
            cauldronInfos[2] = CauldronInfo({cauldron: maxBalanceCauldron, version: 3, deprecated: true});
            cauldronInfos[3] = CauldronInfo({cauldron: aboveMaxBalanceCauldron, version: 3, deprecated: true});

            vm.prank(cauldronRegistryOwner);
            cauldronRegistry.add(cauldronInfos);

            (canExec, execPayload) = cauldronReducer.checker();
            assertTrue(canExec);
            assertEq(execPayload, abi.encodeCall(CauldronReducer.reduceCompletely, (cauldronsToReduceSupply)));
        }

        vm.expectEmit();
        emit CauldronReducer.LogMaxBalanceChanged(maxBalance - 1);
        vm.prank(cauldronReducerOwner);
        cauldronReducer.setMaxBalance(maxBalance - 1);

        {
            ICauldronV2[] memory cauldronsToReduceSupply = new ICauldronV2[](2);
            cauldronsToReduceSupply[0] = ICauldronV2(maxBalanceCauldron);
            cauldronsToReduceSupply[1] = ICauldronV2(aboveMaxBalanceCauldron);

            (canExec, execPayload) = cauldronReducer.checker();
            assertTrue(canExec);
            assertEq(execPayload, abi.encodeCall(CauldronReducer.reduceCompletely, (cauldronsToReduceSupply)));
        }
    }
}
