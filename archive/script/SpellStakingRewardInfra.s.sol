// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "utils/LayerZeroLib.sol";
import "periphery/CauldronFeeWithdrawer.sol";
import "periphery/SpellStakingRewardDistributor.sol";
import "mixins/Create3Factory.sol";
import "forge-std/console2.sol";

contract SpellStakingRewardInfraScript is BaseScript {
    using DeployerFunctions for Deployer;

    // CREATE3 salts
    bytes32 constant CAULDRON_FEE_WITHDRAWER_SALT = keccak256(bytes("CauldronFeeWithdrawer-v1"));
    bytes32 constant SPELL_STAKING_REWARD_DISTRIBUTOR_SALT = keccak256(bytes("SpellStakingRewardDistributor-v1"));

    function deploy() public returns (CauldronFeeWithdrawer withdrawer, SpellStakingRewardDistributor distributor) {
        deployer.setAutoBroadcast(false);

        IERC20 mim = IERC20(toolkit.getAddress(block.chainid, "mim"));
        address safe = toolkit.getAddress(block.chainid, "safe.ops");
        address mimProvider = toolkit.getAddress(block.chainid, "safe.main");

        vm.startBroadcast();

        withdrawer = CauldronFeeWithdrawer(
            payable(
                deployUsingCreate3(
                    string.concat(toolkit.getChainName(block.chainid), "_CauldronFeeWithdrawer"),
                    CAULDRON_FEE_WITHDRAWER_SALT,
                    "CauldronFeeWithdrawer.sol:CauldronFeeWithdrawer",
                    abi.encode(tx.origin, mim, ILzOFTV2(toolkit.getAddress(block.chainid, "oftv2"))),
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
        } else if (block.chainid == ChainId.Fantom) {
            _deployKava(withdrawer, mimProvider);
        } else {
            revert("SpellStakingStackScript: unsupported chain");
        }

        console2.log("chainId", block.chainid);
        console2.log("CauldronFeeWithdrawer deployed at %s", address(withdrawer));

        CauldronInfo[] memory cauldronInfos = toolkit.getCauldrons(block.chainid, true);
        require(cauldronInfos.length > 0, "SpellStakingStackScript: no cauldron found");

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

        if (!testing()) {
            if (withdrawer.owner() != safe) {
                withdrawer.transferOwnership(safe);
            }
        }

        vm.stopBroadcast();
    }

    function _deployMainnet(
        CauldronFeeWithdrawer withdrawer,
        address safe,
        address mimProvider
    ) public returns (SpellStakingRewardDistributor distributor) {
        distributor = SpellStakingRewardDistributor(
            payable(
                deployUsingCreate3(
                    "Mainnet_SpellStakingRewardDistributor",
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
        address mainnetDistributor;
        if (!testing()) {
            mainnetDistributor = vm.envAddress("MAINNET_DISTRIBUTOR");
            console2.log("Using MAINNET_DISTRIBUTOR", mainnetDistributor);
        }

        withdrawer.setParameters(mimProvider, mainnetDistributor, address(withdrawer));
        withdrawer.setOperator(toolkit.getAddress(block.chainid, "safe.devOps.gelatoProxy"), true);

        withdrawer.setBentoBox(IBentoBoxV1(toolkit.getAddress(block.chainid, "degenBox1")), true);
        withdrawer.setBentoBox(IBentoBoxV1(toolkit.getAddress(block.chainid, "degenBox2")), true);
    }

    function _deployArbitrum(CauldronFeeWithdrawer withdrawer, address mimProvider) public {
        address mainnetDistributor;
        if (!testing()) {
            mainnetDistributor = vm.envAddress("MAINNET_DISTRIBUTOR");
            console2.log("Using MAINNET_DISTRIBUTOR", mainnetDistributor);
        }

        withdrawer.setParameters(mimProvider, mainnetDistributor, address(withdrawer));
        withdrawer.setOperator(toolkit.getAddress(block.chainid, "safe.devOps.gelatoProxy"), true);

        withdrawer.setBentoBox(IBentoBoxV1(toolkit.getAddress(block.chainid, "sushiBentoBox")), true);
        withdrawer.setBentoBox(IBentoBoxV1(toolkit.getAddress(block.chainid, "degenBox")), true);
    }

    function _deployFantom(CauldronFeeWithdrawer withdrawer, address mimProvider) public {
        address mainnetDistributor;
        if (!testing()) {
            mainnetDistributor = vm.envAddress("MAINNET_DISTRIBUTOR");
            console2.log("Using MAINNET_DISTRIBUTOR", mainnetDistributor);
        }

        withdrawer.setParameters(mimProvider, mainnetDistributor, address(withdrawer));
        withdrawer.setOperator(toolkit.getAddress(block.chainid, "safe.devOps.gelatoProxy"), true);

        withdrawer.setBentoBox(IBentoBoxV1(toolkit.getAddress(block.chainid, "sushiBentoBox")), true);
        withdrawer.setBentoBox(IBentoBoxV1(toolkit.getAddress(block.chainid, "degenBox")), true);
    }

    function _deployKava(CauldronFeeWithdrawer withdrawer, address mimProvider) public {
        address mainnetDistributor;
        if (!testing()) {
            mainnetDistributor = vm.envAddress("MAINNET_DISTRIBUTOR");
            console2.log("Using MAINNET_DISTRIBUTOR", mainnetDistributor);
        }

        withdrawer.setParameters(mimProvider, mainnetDistributor, address(withdrawer));
        //withdrawer.setOperator(toolkit.getAddress(block.chainid, "safe.devOps.gelatoProxy"), true);

        withdrawer.setBentoBox(IBentoBoxV1(toolkit.getAddress(block.chainid, "degenBox")), true);
    }
}
