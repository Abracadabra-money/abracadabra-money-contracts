// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/BlastUpdateMIMFeeHandler.s.sol";
import {LzIndirectOFTV2} from "tokens/LzIndirectOFTV2.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ILzCommonOFT} from "interfaces/ILayerZero.sol";

contract BlastUpdateMIMFeeHandlerTest is BaseTest {
    using SafeTransferLib for address;

    address constant MIM_WHALE = 0xC8f5Eb8A632f9600D1c7BC91e97dAD5f8B1e3748;

    BlastLzOFTV2FeeHandler feeHandlerV2;
    BlastLzOFTV2Wrapper wrapper;
    LzIndirectOFTV2 oft;
    address mim;

    function setUp() public override {
        fork(ChainId.Blast, 5362574);
        super.setUp();

        BlastUpdateMIMFeeHandlerScript script = new BlastUpdateMIMFeeHandlerScript();
        script.setTesting(true);

        (feeHandlerV2, wrapper) = script.deploy();

        oft = LzIndirectOFTV2(payable(toolkit.getAddress("oftv2", ChainId.Blast)));
        mim = toolkit.getAddress("mim", ChainId.Blast);

        // update fee handler
        pushPrank(oft.owner());
        oft.setFeeHandler(feeHandlerV2);
        popPrank();
    }

    function testForceUsingWrapper() public {
        pushPrank(MIM_WHALE);
        mim.safeTransfer(address(alice), 100 ether);
        popPrank();

        pushPrank(alice);
        _testSendFromChainUsingWrapper(alice, 100 ether);
        popPrank();
    }

    function _testSendFromChainUsingWrapper(address account, uint amount) private {
        pushPrank(MIM_WHALE);
        mim.safeTransfer(address(account), amount);
        popPrank();

        mim.safeApprove(address(wrapper), amount);

        bytes memory adapterParams = abi.encodePacked(uint16(1), uint256(200_000));
        bytes32 toAddress = bytes32(uint256(uint160(account)));

        (uint fee, ) = wrapper.estimateSendFeeV2(LayerZeroChainId.Arbitrum, toAddress, amount, adapterParams);

        ILzCommonOFT.LzCallParams memory params = ILzCommonOFT.LzCallParams({
            refundAddress: payable(account),
            zroPaymentAddress: address(0),
            adapterParams: adapterParams
        });

        vm.deal(account, fee);

        uint mimBalanceBefore = mim.balanceOf(account);

        wrapper.sendProxyOFTV2{value: fee}(LayerZeroChainId.Arbitrum, toAddress, amount, params);
        assertEq(mim.balanceOf(account), mimBalanceBefore - amount, "mim balance is not correct");
        uint balance = address(wrapper).balance;
        address owner = toolkit.getAddress("safe.yields", block.chainid);
        uint256 nativeBalanceBefore = owner.balance;
        wrapper.withdrawFees();
        assertEq(owner.balance, nativeBalanceBefore + balance, "native balance is not correct");
    }
}