// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import {CauldronInfo as ToolkitCauldronInfo} from "utils/Toolkit.sol";
import {LayerZeroLib} from "utils/LayerZeroLib.sol";
import {CauldronFeeWithdrawer} from "/periphery/CauldronFeeWithdrawer.sol";
import {SpellStakingRewardDistributor} from "/staking/distributors/SpellStakingRewardDistributor.sol";
import {IBentoBoxV1} from "/interfaces/IBentoBoxV1.sol";
import "forge-std/console2.sol";

contract SpellStakingRewardInfraScript is BaseScript {
    bytes32 constant CAULDRON_FEE_WITHDRAWER_SALT = keccak256(bytes("CauldronFeeWithdrawer-1723211086"));
    bytes32 constant SPELL_STAKING_REWARD_DISTRIBUTOR_SALT = keccak256(bytes("SpellStakingRewardDistributor-v1"));

    address mainnetDistributor;

    function deploy() public returns (CauldronFeeWithdrawer withdrawer, SpellStakingRewardDistributor distributor) {
        address mim = toolkit.getAddress("mim");
        address safe = toolkit.getAddress("safe.ops");
        address mimProvider = toolkit.getAddress("safe.main");
        mainnetDistributor = toolkit.getAddress(ChainId.Mainnet, "spellStakingDistributor");

        vm.startBroadcast();

        withdrawer = CauldronFeeWithdrawer(
            payable(
                deployUsingCreate3(
                    "CauldronFeeWithdrawer",
                    CAULDRON_FEE_WITHDRAWER_SALT,
                    "CauldronFeeWithdrawer.sol:CauldronFeeWithdrawer",
                    abi.encode(tx.origin, mim, toolkit.getAddress(block.chainid, "oftv2")),
                    0
                )
            )
        );

        if (block.chainid == ChainId.Mainnet) {
            distributor = _deployMainnet(withdrawer, safe, mimProvider);
        } else if (block.chainid == ChainId.Avalanche) {
            _deployAvalanche(withdrawer, mimProvider);
        } else if (block.chainid == ChainId.Arbitrum) {
            _deployArbitrum(withdrawer, mimProvider);
        } else if (block.chainid == ChainId.Fantom) {
            _deployFantom(withdrawer, mimProvider);
        } else if (block.chainid == ChainId.Kava) {
            _deployKava(withdrawer, mimProvider);
        } else if (block.chainid == ChainId.Blast) {
            _deployBlast(withdrawer, mimProvider);
        } else {
            revert("SpellStakingStackScript: unsupported chain");
        }

        ToolkitCauldronInfo[] memory cauldronInfos = toolkit.getCauldrons(block.chainid, true, this._cauldronPredicate);
        require(cauldronInfos.length > 0, "SpellStakingStackScript: no cauldron found");

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

    // Support for fork testing at a specific block
    function _cauldronPredicate(address, bool, uint8, string memory, uint256 creationBlock) external view returns (bool) {
        return creationBlock <= block.number;
    }

    function _deployMainnet(
        CauldronFeeWithdrawer withdrawer,
        address safe,
        address mimProvider
    ) public returns (SpellStakingRewardDistributor distributor) {
        distributor = SpellStakingRewardDistributor(
            payable(
                deployUsingCreate3(
                    "SpellStakingRewardDistributor",
                    SPELL_STAKING_REWARD_DISTRIBUTOR_SALT,
                    "SpellStakingRewardDistributor.sol:SpellStakingRewardDistributor",
                    abi.encode(tx.origin),
                    0
                )
            )
        );

        if (
            withdrawer.mimProvider() != mimProvider ||
            withdrawer.bridgeRecipient() != 0 ||
            withdrawer.mimWithdrawRecipient() != address(distributor)
        ) {
            withdrawer.setParameters(mimProvider, address(0), address(distributor));
        }

        // for gelato web3 functions
        if (!withdrawer.operators(toolkit.getAddress(block.chainid, "safe.devOps.gelatoProxy"))) {
            withdrawer.setOperator(toolkit.getAddress(block.chainid, "safe.devOps.gelatoProxy"), true);
        }
        if (!distributor.operators(toolkit.getAddress(block.chainid, "safe.devOps.gelatoProxy"))) {
            distributor.setOperator(toolkit.getAddress(block.chainid, "safe.devOps.gelatoProxy"), true);
        }

        withdrawer.setBentoBox(IBentoBoxV1(toolkit.getAddress(block.chainid, "sushiBentoBox")), true);
        withdrawer.setBentoBox(IBentoBoxV1(toolkit.getAddress(block.chainid, "degenBox")), true);

        if (!testing()) {
            // feeTo override
            // Handle the fees independently for these two cauldrons by redirecting to ops safe
            withdrawer.setFeeToOverride(0x7d8dF3E4D06B0e19960c19Ee673c0823BEB90815, safe);
            withdrawer.setFeeToOverride(0x207763511da879a900973A5E092382117C3c1588, safe);

            if (distributor.owner() != safe) {
                distributor.transferOwnership(safe);
            }
        }
    }

    function _deployAvalanche(CauldronFeeWithdrawer withdrawer, address mimProvider) public {
        withdrawer.setParameters(mimProvider, mainnetDistributor, address(withdrawer));
        withdrawer.setOperator(toolkit.getAddress(block.chainid, "safe.devOps.gelatoProxy"), true);

        withdrawer.setBentoBox(IBentoBoxV1(toolkit.getAddress(block.chainid, "degenBox1")), true);
        withdrawer.setBentoBox(IBentoBoxV1(toolkit.getAddress(block.chainid, "degenBox2")), true);
    }

    function _deployArbitrum(CauldronFeeWithdrawer withdrawer, address mimProvider) public {
        withdrawer.setParameters(mimProvider, mainnetDistributor, address(withdrawer));
        withdrawer.setOperator(toolkit.getAddress(block.chainid, "safe.devOps.gelatoProxy"), true);

        withdrawer.setBentoBox(IBentoBoxV1(toolkit.getAddress(block.chainid, "sushiBentoBox")), true);
        withdrawer.setBentoBox(IBentoBoxV1(toolkit.getAddress(block.chainid, "degenBox")), true);
    }

    function _deployFantom(CauldronFeeWithdrawer withdrawer, address mimProvider) public {
        withdrawer.setParameters(mimProvider, mainnetDistributor, address(withdrawer));
        withdrawer.setOperator(toolkit.getAddress(block.chainid, "safe.devOps.gelatoProxy"), true);

        withdrawer.setBentoBox(IBentoBoxV1(toolkit.getAddress(block.chainid, "sushiBentoBox")), true);
        withdrawer.setBentoBox(IBentoBoxV1(toolkit.getAddress(block.chainid, "degenBox")), true);
    }

    function _deployKava(CauldronFeeWithdrawer withdrawer, address mimProvider) public {
        withdrawer.setParameters(mimProvider, mainnetDistributor, address(withdrawer));
        withdrawer.setOperator(0xfB3485c2e209A5cfBDC1447674256578f1A80eE3, true); // calibur
        withdrawer.setOperator(0x000000E6cee66A117a0B436670C1E897A5D7Fcf9, true); // dreamy

        withdrawer.setBentoBox(IBentoBoxV1(toolkit.getAddress(block.chainid, "degenBox")), true);
    }

    function _deployBlast(CauldronFeeWithdrawer withdrawer, address mimProvider) public {
        withdrawer.setParameters(mimProvider, mainnetDistributor, address(withdrawer));
        withdrawer.setOperator(toolkit.getAddress(block.chainid, "safe.devOps.gelatoProxy"), true);

        withdrawer.setBentoBox(IBentoBoxV1(toolkit.getAddress(block.chainid, "degenBox")), true);
    }
}
