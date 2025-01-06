// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import {CauldronInfo as ToolkitCauldronInfo, CauldronStatus} from "utils/Toolkit.sol";
import {LayerZeroLib} from "utils/LayerZeroLib.sol";
import {CauldronFeeWithdrawer} from "/periphery/CauldronFeeWithdrawer.sol";
import {IBentoBoxV1} from "/interfaces/IBentoBoxV1.sol";
import "forge-std/console2.sol";

contract CauldronFeeWithdrawerScript is BaseScript {
    bytes32 constant CAULDRON_FEE_WITHDRAWER_SALT = keccak256(bytes("CauldronFeeWithdrawer-1736192691"));

    address mainnetDistributor;

    function deploy() public returns (CauldronFeeWithdrawer withdrawer) {
        address safe = toolkit.getAddress("safe.ops");
        address mimProvider = toolkit.getAddress("safe.main");

        vm.startBroadcast();

        withdrawer = CauldronFeeWithdrawer(
            payable(
                deployUsingCreate3(
                    "CauldronFeeWithdrawer",
                    CAULDRON_FEE_WITHDRAWER_SALT,
                    "CauldronFeeWithdrawer.sol:CauldronFeeWithdrawer",
                    abi.encode(toolkit.getAddress(block.chainid, "mim.oftv2"), tx.origin),
                    0
                )
            )
        );

        if (block.chainid == ChainId.Mainnet) {
            _deployMainnet(withdrawer, safe, mimProvider);
        } else if (block.chainid == ChainId.Avalanche) {
            _deployAvalanche(withdrawer, mimProvider);
        } else if (block.chainid == ChainId.Arbitrum) {
            _deployArbitrum(withdrawer, mimProvider);
        } else if (block.chainid == ChainId.Fantom) {
            _deployFantom(withdrawer, mimProvider);
        } else if (block.chainid == ChainId.Kava) {
            _deployKava(withdrawer, mimProvider);
        } else if (block.chainid == ChainId.Blast || block.chainid == ChainId.Optimism || block.chainid == ChainId.BSC) {
            _deployGeneric(withdrawer, mimProvider);
        } else {
            revert("SpellStakingRewardInfraScript: unsupported chain");
        }

        ToolkitCauldronInfo[] memory cauldronInfos = toolkit.getCauldrons(block.chainid, this._cauldronPredicate);
        require(cauldronInfos.length > 0, "SpellStakingRewardInfraScript: no cauldron found");

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

        if (!testing()) {
            if (withdrawer.owner() != safe) {
                withdrawer.transferOwnership(safe);
            }
        }

        vm.stopBroadcast();
    }

    // Support for fork testing at a specific block and not removed
    function _cauldronPredicate(address, CauldronStatus status, uint8, string memory, uint256 creationBlock) external view returns (bool) {
        return creationBlock <= block.number && status != CauldronStatus.Removed;
    }

    function _deployMainnet(CauldronFeeWithdrawer withdrawer, address safe, address mimProvider) public {
        if (withdrawer.mimProvider() != mimProvider) {
            withdrawer.setMimProvider(mimProvider);
        }

        // for gelato web3 functions
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

    function _deployAvalanche(CauldronFeeWithdrawer withdrawer, address mimProvider) public {
        if (withdrawer.mimProvider() != mimProvider) {
            withdrawer.setMimProvider(mimProvider);
        }
        withdrawer.setOperator(toolkit.getAddress("safe.devOps.gelatoProxy"), true);

        withdrawer.setBentoBox(toolkit.getAddress("degenBox1"), true);
        withdrawer.setBentoBox(toolkit.getAddress("degenBox2"), true);
    }

    function _deployArbitrum(CauldronFeeWithdrawer withdrawer, address mimProvider) public {
        if (withdrawer.mimProvider() != mimProvider) {
            withdrawer.setMimProvider(mimProvider);
        }
        withdrawer.setOperator(toolkit.getAddress("safe.devOps.gelatoProxy"), true);

        withdrawer.setBentoBox(toolkit.getAddress("sushiBentoBox"), true);
        withdrawer.setBentoBox(toolkit.getAddress("degenBox"), true);
    }

    function _deployFantom(CauldronFeeWithdrawer withdrawer, address mimProvider) public {
        if (withdrawer.mimProvider() != mimProvider) {
            withdrawer.setMimProvider(mimProvider);
        }
        withdrawer.setOperator(toolkit.getAddress("safe.devOps.gelatoProxy"), true);

        withdrawer.setBentoBox(toolkit.getAddress("sushiBentoBox"), true);
        withdrawer.setBentoBox(toolkit.getAddress("degenBox"), true);
    }

    function _deployKava(CauldronFeeWithdrawer withdrawer, address mimProvider) public {
        if (withdrawer.mimProvider() != mimProvider) {
            withdrawer.setMimProvider(mimProvider);
        }
        withdrawer.setOperator(0xfB3485c2e209A5cfBDC1447674256578f1A80eE3, true); // calibur
        withdrawer.setOperator(0x000000E6cee66A117a0B436670C1E897A5D7Fcf9, true); // dreamy

        withdrawer.setBentoBox(toolkit.getAddress("degenBox"), true);
    }

    function _deployGeneric(CauldronFeeWithdrawer withdrawer, address mimProvider) public {
        if (withdrawer.mimProvider() != mimProvider) {
            withdrawer.setMimProvider(mimProvider);
        }
        withdrawer.setOperator(toolkit.getAddress("safe.devOps.gelatoProxy"), true);

        withdrawer.setBentoBox(toolkit.getAddress("degenBox"), true);
    }
}
