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
        } else if (block.chainid == ChainId.Avalanche) {
            _deployAvalanche(withdrawer);
        } else if (block.chainid == ChainId.Arbitrum) {
            _deployArbitrum(withdrawer);
        } else if (block.chainid == ChainId.Fantom) {
            _deployFantom(withdrawer);
        } else if (block.chainid == ChainId.Kava) {
            _deployKava(withdrawer);
        } else {
            _deployDefault(withdrawer);
        }

        if (withdrawer.mimProvider() != mimProvider) {
            withdrawer.setMimProvider(mimProvider);
        }

        if (!testing()) {
            ToolkitCauldronInfo[] memory cauldronInfos = toolkit.getCauldrons(block.chainid, this._cauldronPredicate);
            require(cauldronInfos.length > 0, "no cauldron found");

            address[] memory cauldrons = new address[](cauldronInfos.length);
            uint8[] memory versions = new uint8[](cauldronInfos.length);
            bool[] memory enabled = new bool[](cauldronInfos.length);

            for (uint256 i = 0; i < cauldronInfos.length; i++) {
                ToolkitCauldronInfo memory cauldronInfo = cauldronInfos[i];
                cauldrons[i] = cauldronInfo.cauldron;
                versions[i] = cauldronInfo.version;
                enabled[i] = true;
            }

            withdrawer.setCauldrons(cauldrons, versions, enabled);

            if (withdrawer.owner() != safe) {
                withdrawer.transferOwnership(safe);
            }
        }

        vm.stopBroadcast();
    }

    // filter out removed cauldrons
    function _cauldronPredicate(address, CauldronStatus status, uint8, string memory, uint256) external pure returns (bool) {
        return status != CauldronStatus.Removed;
    }

    function _deployMainnet(CauldronFeeWithdrawer withdrawer, address safe) public {
        if (!withdrawer.operators(toolkit.getAddress("safe.devOps.gelatoProxy"))) {
            withdrawer.setOperator(toolkit.getAddress("safe.devOps.gelatoProxy"), true);
        }

        withdrawer.setBentoBox(toolkit.getAddress("sushiBentoBox"), true);
        withdrawer.setBentoBox(toolkit.getAddress("degenBox"), true);

        if (!testing()) {
            // feeTo override
            // Handle the fees independently for these two cauldrons by redirecting to ops safe
            withdrawer.setFeeToOverride(0x7d8dF3E4D06B0e19960c19Ee673c0823BEB90815, safe);
            withdrawer.setFeeToOverride(0x207763511da879a900973A5E092382117C3c1588, safe);
        }
    }

    function _deployAvalanche(CauldronFeeWithdrawer withdrawer) public {
        if (!withdrawer.operators(toolkit.getAddress("safe.devOps.gelatoProxy"))) {
            withdrawer.setOperator(toolkit.getAddress("safe.devOps.gelatoProxy"), true);
        }

        withdrawer.setBentoBox(toolkit.getAddress("degenBox1"), true);
        withdrawer.setBentoBox(toolkit.getAddress("degenBox2"), true);
    }

    function _deployArbitrum(CauldronFeeWithdrawer withdrawer) public {
        if (!withdrawer.operators(toolkit.getAddress("safe.devOps.gelatoProxy"))) {
            withdrawer.setOperator(toolkit.getAddress("safe.devOps.gelatoProxy"), true);
        }

        withdrawer.setBentoBox(toolkit.getAddress("sushiBentoBox"), true);
        withdrawer.setBentoBox(toolkit.getAddress("degenBox"), true);
    }

    function _deployFantom(CauldronFeeWithdrawer withdrawer) public {
        if (!withdrawer.operators(toolkit.getAddress("safe.devOps.gelatoProxy"))) {
            withdrawer.setOperator(toolkit.getAddress("safe.devOps.gelatoProxy"), true);
        }

        withdrawer.setBentoBox(toolkit.getAddress("sushiBentoBox"), true);
        withdrawer.setBentoBox(toolkit.getAddress("degenBox"), true);
    }

    function _deployKava(CauldronFeeWithdrawer withdrawer) public {
        if (!withdrawer.operators(0xfB3485c2e209A5cfBDC1447674256578f1A80eE3)) {
            withdrawer.setOperator(0xfB3485c2e209A5cfBDC1447674256578f1A80eE3, true); // calibur
        }

        if (!withdrawer.operators(0x000000E6cee66A117a0B436670C1E897A5D7Fcf9)) {
            withdrawer.setOperator(0x000000E6cee66A117a0B436670C1E897A5D7Fcf9, true); // dreamy
        }

        withdrawer.setBentoBox(toolkit.getAddress("degenBox"), true);
    }

    function _deployDefault(CauldronFeeWithdrawer withdrawer) public {
        if (!withdrawer.operators(toolkit.getAddress("safe.devOps.gelatoProxy"))) {
            withdrawer.setOperator(toolkit.getAddress("safe.devOps.gelatoProxy"), true);
        }

        withdrawer.setBentoBox(toolkit.getAddress("degenBox"), true);
    }
}
