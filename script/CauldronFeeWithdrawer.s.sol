// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import {CauldronInfo as ToolkitCauldronInfo, CauldronStatus} from "utils/Toolkit.sol";
import {LayerZeroLib} from "utils/LayerZeroLib.sol";
import {CauldronFeeWithdrawer} from "/periphery/CauldronFeeWithdrawer.sol";
import {IBentoBoxV1} from "/interfaces/IBentoBoxV1.sol";

contract CauldronFeeWithdrawerScript is BaseScript {
    bytes32 constant CAULDRON_FEE_WITHDRAWER_SALT = keccak256(bytes("CauldronFeeWithdrawer-1736278726"));

    function deploy() public returns (CauldronFeeWithdrawer withdrawer) {
        address safe = toolkit.getAddress("safe.ops");
        address mimProvider = toolkit.getAddress("safe.main");
        address registry = toolkit.getAddress("cauldronRegistry");

        vm.startBroadcast();

        withdrawer = CauldronFeeWithdrawer(
            payable(
                deployUpgradeableUsingCreate3(
                    "CauldronFeeWithdrawer",
                    CAULDRON_FEE_WITHDRAWER_SALT,
                    "CauldronFeeWithdrawer.sol:CauldronFeeWithdrawer",
                    abi.encode(toolkit.getAddress(block.chainid, "mim.oftv2"), address(0)), // constructor
                    abi.encodeCall(CauldronFeeWithdrawer.initialize, (tx.origin)) // initializer
                )
            )
        );

        if (block.chainid == ChainId.Mainnet) {
            _deployMainnet(withdrawer, safe);
        } else if (block.chainid == ChainId.Kava) {
            _deployKava(withdrawer);
        } else {
            _deployDefault(withdrawer);
        }

        withdrawer.setMimProvider(mimProvider);
        withdrawer.setRegistry(registry);
        withdrawer.setFeeParameters(toolkit.getAddress("safe.yields"), 5000); // 50% to safe.yields treasury

        if (!testing()) {
            if (withdrawer.owner() != safe) {
                withdrawer.transferOwnership(safe);
            }
        }

        vm.stopBroadcast();
    }

    function _deployMainnet(CauldronFeeWithdrawer withdrawer, address safe) public {
        if (!withdrawer.operators(toolkit.getAddress("safe.devOps.gelatoProxy"))) {
            withdrawer.setOperator(toolkit.getAddress("safe.devOps.gelatoProxy"), true);
        }

        if (!testing()) {
            // feeTo override
            // Handle the fees independently for these two cauldrons by redirecting to ops safe
            withdrawer.setFeeToOverride(0x7d8dF3E4D06B0e19960c19Ee673c0823BEB90815, safe);
            withdrawer.setFeeToOverride(0x207763511da879a900973A5E092382117C3c1588, safe);
        }
    }

    function _deployKava(CauldronFeeWithdrawer withdrawer) public {
        if (!withdrawer.operators(0xfB3485c2e209A5cfBDC1447674256578f1A80eE3)) {
            withdrawer.setOperator(0xfB3485c2e209A5cfBDC1447674256578f1A80eE3, true); // calibur
        }

        if (!withdrawer.operators(0x000000E6cee66A117a0B436670C1E897A5D7Fcf9)) {
            withdrawer.setOperator(0x000000E6cee66A117a0B436670C1E897A5D7Fcf9, true); // dreamy
        }
    }

    function _deployDefault(CauldronFeeWithdrawer withdrawer) public {
        if (!withdrawer.operators(toolkit.getAddress("safe.devOps.gelatoProxy"))) {
            withdrawer.setOperator(toolkit.getAddress("safe.devOps.gelatoProxy"), true);
        }
    }
}
