// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "utils/LayerZeroLib.sol";
import "periphery/CauldronFeeWithdrawer.sol";
import "periphery/SpellStakingRewardDistributor.sol";
import "mixins/Create3Factory.sol";
import "solmate/utils/CREATE3.sol";
import "forge-std/console2.sol";

contract SpellStakingRewardInfraScript is BaseScript {
    using DeployerFunctions for Deployer;

    // CREATE3 salts
    bytes32 constant CAULDRON_FEE_WITHDRAWER_SALT = keccak256(bytes("CauldronFeeWithdrawer-v1"));
    bytes32 constant SPELL_STAKING_REWARD_DISTRIBUTOR_SALT = keccak256(bytes("SpellStakingRewardDistributor-v1"));

    function deploy() public returns (CauldronFeeWithdrawer withdrawer, SpellStakingRewardDistributor distributor) {
        deployer.setAutoBroadcast(false);

        Create3Factory factory = Create3Factory(constants.getAddress(ChainId.All, "create3Factory"));
        IERC20 mim = IERC20(constants.getAddress(block.chainid, "mim"));
        address safe = constants.getAddress(block.chainid, "safe.ops");
        address mimProvider = constants.getAddress(block.chainid, "safe.main");

        vm.startBroadcast();
        console2.log("tx.sender", address(tx.origin));

        if (block.chainid == ChainId.Mainnet) {
            (withdrawer, distributor) = _deployMainnet(factory, mim, safe, mimProvider);
        } else if (block.chainid == ChainId.Avalanche) {
            withdrawer = _deployAvalanche(factory, mim, mimProvider);
        } else if (block.chainid == ChainId.Arbitrum) {
            withdrawer = _deployArbitrum(factory, mim, mimProvider);
        } else if (block.chainid == ChainId.Fantom) {
            withdrawer = _deployFantom(factory, mim, mimProvider);
        } else {
            revert("SpellStakingStackScript: unsupported chain");
        }

        console2.log("chainId", block.chainid);
        console2.log("CauldronFeeWithdrawer deployed at %s", address(withdrawer));

        //if (address(distributor) != address(0)) {
        //    console2.log("SpellStakingRewardDistributor deployed at %s", address(distributor));
        //}

        CauldronInfo[] memory cauldronInfos = constants.getCauldrons(block.chainid, true);
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

        if (!testing) {
            if (withdrawer.owner() != safe) {
                withdrawer.transferOwnership(safe);
            }
        }

        vm.stopBroadcast();
    }

    function _deployMainnet(
        Create3Factory factory,
        IERC20 mim,
        address safe,
        address mimProvider
    ) public returns (CauldronFeeWithdrawer withdrawer, SpellStakingRewardDistributor distributor) {
        if (testing) {
            deployer.ignoreDeployment("Mainnet_CauldronFeeWithdrawer");
        }
        if (deployer.has("Mainnet_CauldronFeeWithdrawer")) {
            withdrawer = CauldronFeeWithdrawer(deployer.getAddress("Mainnet_CauldronFeeWithdrawer"));
        } else {
            withdrawer = CauldronFeeWithdrawer(
                payable(
                    factory.deploy(
                        CAULDRON_FEE_WITHDRAWER_SALT,
                        abi.encodePacked(
                            type(CauldronFeeWithdrawer).creationCode,
                            abi.encode(tx.origin, mim, ILzOFTV2(constants.getAddress(block.chainid, "oftv2"))) // Mainnet LzOFTV2 Proxy
                        ),
                        0
                    )
                )
            );
        }
        if (testing) {
            deployer.ignoreDeployment("Mainnet_SpellStakingRewardDistributor");
        }
        if (deployer.has("Mainnet_SpellStakingRewardDistributor")) {
            distributor = SpellStakingRewardDistributor(deployer.getAddress("Mainnet_SpellStakingRewardDistributor"));
        } else {
            distributor = SpellStakingRewardDistributor(
                payable(
                    factory.deploy(
                        SPELL_STAKING_REWARD_DISTRIBUTOR_SALT,
                        abi.encodePacked(type(SpellStakingRewardDistributor).creationCode, abi.encode(tx.origin)),
                        0
                    )
                )
            );
        }

        if (
            withdrawer.mimProvider() != mimProvider ||
            withdrawer.bridgeRecipient() != 0 ||
            withdrawer.mimWithdrawRecipient() != address(distributor)
        ) {
            withdrawer.setParameters(mimProvider, address(0), address(distributor));
        }

        // for gelato web3 functions
        if (!withdrawer.operators(constants.getAddress(block.chainid, "safe.devOps.gelatoProxy"))) {
            withdrawer.setOperator(constants.getAddress(block.chainid, "safe.devOps.gelatoProxy"), true);
        }
        if (!distributor.operators(constants.getAddress(block.chainid, "safe.devOps.gelatoProxy"))) {
            distributor.setOperator(constants.getAddress(block.chainid, "safe.devOps.gelatoProxy"), true);
        }

        withdrawer.setBentoBox(IBentoBoxV1(constants.getAddress(block.chainid, "sushiBentoBox")), true);
        withdrawer.setBentoBox(IBentoBoxV1(constants.getAddress(block.chainid, "degenBox")), true);

        if (!testing) {
            // feeTo override
            // Handle the fees independently for these two cauldrons by redirecting to ops safe
            withdrawer.setFeeToOverride(0x7d8dF3E4D06B0e19960c19Ee673c0823BEB90815, safe);
            withdrawer.setFeeToOverride(0x207763511da879a900973A5E092382117C3c1588, safe);

            if (distributor.owner() != safe) {
                distributor.transferOwnership(safe);
            }
        }
    }

    function _deployAvalanche(Create3Factory factory, IERC20 mim, address mimProvider) public returns (CauldronFeeWithdrawer withdrawer) {
        if (testing) {
            deployer.ignoreDeployment("Avalanche_CauldronFeeWithdrawer");
        }
        if (deployer.has("Avalanche_CauldronFeeWithdrawer")) {
            withdrawer = CauldronFeeWithdrawer(deployer.getAddress("Avalanche_CauldronFeeWithdrawer"));
        } else {
            withdrawer = CauldronFeeWithdrawer(
                payable(
                    factory.deploy(
                        CAULDRON_FEE_WITHDRAWER_SALT,
                        abi.encodePacked(
                            type(CauldronFeeWithdrawer).creationCode,
                            abi.encode(tx.origin, mim, ILzOFTV2(constants.getAddress(block.chainid, "oftv2"))) // LzOFTV2 IndirectProxy
                        ),
                        0
                    )
                )
            );
        }

        address mainnetDistributor;
        if (!testing) {
            mainnetDistributor = vm.envAddress("MAINNET_DISTRIBUTOR");
            console2.log("Using MAINNET_DISTRIBUTOR", mainnetDistributor);
        }

        withdrawer.setParameters(mimProvider, mainnetDistributor, address(withdrawer));
        withdrawer.setOperator(constants.getAddress(block.chainid, "safe.devOps.gelatoProxy"), true);

        withdrawer.setBentoBox(IBentoBoxV1(constants.getAddress(block.chainid, "degenBox1")), true);
        withdrawer.setBentoBox(IBentoBoxV1(constants.getAddress(block.chainid, "degenBox2")), true);
    }

    function _deployArbitrum(Create3Factory factory, IERC20 mim, address mimProvider) public returns (CauldronFeeWithdrawer withdrawer) {
        if (testing) {
            deployer.ignoreDeployment("Arbitrum_CauldronFeeWithdrawer");
        }
        if (deployer.has("Arbitrum_CauldronFeeWithdrawer")) {
            withdrawer = CauldronFeeWithdrawer(deployer.getAddress("Arbitrum_CauldronFeeWithdrawer"));
        } else {
            withdrawer = CauldronFeeWithdrawer(
                payable(
                    factory.deploy(
                        CAULDRON_FEE_WITHDRAWER_SALT,
                        abi.encodePacked(
                            type(CauldronFeeWithdrawer).creationCode,
                            abi.encode(tx.origin, mim, ILzOFTV2(constants.getAddress(block.chainid, "oftv2"))) // LzOFTV2 IndirectProxy
                        ),
                        0
                    )
                )
            );
        }

        address mainnetDistributor;
        if (!testing) {
            mainnetDistributor = vm.envAddress("MAINNET_DISTRIBUTOR");
            console2.log("Using MAINNET_DISTRIBUTOR", mainnetDistributor);
        }

        withdrawer.setParameters(mimProvider, mainnetDistributor, address(withdrawer));
        withdrawer.setOperator(constants.getAddress(block.chainid, "safe.devOps.gelatoProxy"), true);

        withdrawer.setBentoBox(IBentoBoxV1(constants.getAddress(block.chainid, "sushiBentoBox")), true);
        withdrawer.setBentoBox(IBentoBoxV1(constants.getAddress(block.chainid, "degenBox")), true);
    }

    function _deployFantom(Create3Factory factory, IERC20 mim, address mimProvider) public returns (CauldronFeeWithdrawer withdrawer) {
        if (testing) {
            deployer.ignoreDeployment("Fantom_CauldronFeeWithdrawer");
        }
        if (deployer.has("Fantom_CauldronFeeWithdrawer")) {
            withdrawer = CauldronFeeWithdrawer(deployer.getAddress("Fantom_CauldronFeeWithdrawer"));
        } else {
            withdrawer = CauldronFeeWithdrawer(
                payable(
                    factory.deploy(
                        CAULDRON_FEE_WITHDRAWER_SALT,
                        abi.encodePacked(
                            type(CauldronFeeWithdrawer).creationCode,
                            abi.encode(tx.origin, mim, ILzOFTV2(constants.getAddress(block.chainid, "oftv2"))) // LzOFTV2 IndirectProxy
                        ),
                        0
                    )
                )
            );
        }

        address mainnetDistributor;
        if (!testing) {
            mainnetDistributor = vm.envAddress("MAINNET_DISTRIBUTOR");
            console2.log("Using MAINNET_DISTRIBUTOR", mainnetDistributor);
        }

        withdrawer.setParameters(mimProvider, mainnetDistributor, address(withdrawer));
        withdrawer.setOperator(constants.getAddress(block.chainid, "safe.devOps.gelatoProxy"), true);

        withdrawer.setBentoBox(IBentoBoxV1(constants.getAddress(block.chainid, "sushiBentoBox")), true);
        withdrawer.setBentoBox(IBentoBoxV1(constants.getAddress(block.chainid, "degenBox")), true);
    }
}
