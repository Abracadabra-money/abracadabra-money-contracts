// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {MagicLP} from "/mimswap/MagicLP.sol";
import {Registry} from "/mimswap/periphery/Registry.sol";
import {Factory} from "/mimswap/periphery/Factory.sol";
import {Router} from "/mimswap/periphery/Router.sol";
import {FeeRateModel} from "/mimswap/auxiliary/FeeRateModel.sol";
import {BlastTokenRegistry} from "/blast/BlastTokenRegistry.sol";

contract MIMSwapScript is BaseScript {
    string public constant REV = "1.0.0";

    // CREATE3 salts
    bytes32 MAGICLP_SALT = keccak256(bytes(string.concat("MAGICLP_", REV)));
    bytes32 MT_FEERATEMODEL_SALT = keccak256(bytes(string.concat("MT_FEERATEMODEL_", REV)));
    bytes32 REGISTRY_SALT = keccak256(bytes(string.concat("REGISTRY_", REV)));
    bytes32 FACTORY_SALT = keccak256(bytes(string.concat("FACTORY_", REV)));
    bytes32 ROUTER_SALT = keccak256(bytes(string.concat("ROUTER_", REV)));
    bytes32 BLAST_TOKEN_REGISTRY_SALT = keccak256(bytes(string.concat("BLAST_TOKEN_REGISTRY_", REV)));

    address safe;
    address weth;
    address usdb;

    address maintainer = safe;
    address owner = safe;
    address feeTo = safe;

    function deploy()
        public
        returns (MagicLP implementation, FeeRateModel feeRateModel, Registry registry, Factory factory, Router router)
    {
        safe = toolkit.getAddress(block.chainid, "safe.ops");
        weth = toolkit.getAddress(block.chainid, "weth");
        maintainer = safe;
        owner = safe;
        feeTo = safe;

        if (block.chainid == ChainId.Blast) {
            usdb = toolkit.getAddress(block.chainid, "usdb");
            (implementation, feeRateModel, registry, factory, router) = _deployBlast();
        } else {
            revert("unsupported chain");
        }
    }

    function _deployBlast()
        private
        returns (MagicLP implementation, FeeRateModel feeRateModel, Registry registry, Factory factory, Router router)
    {
        vm.startBroadcast();

        // BlastMagicLP implementation
        /*
            forge create --rpc-url https://sepolia.blast.io \
                --constructor-args 0xfB3485c2e209A5cfBDC1447674256578f1A80eE3 0xfB3485c2e209A5cfBDC1447674256578f1A80eE3 \
                --private-key $PRIVATE_KEY \
                src/mixins/BlastMagicLP.sol:BlastMagicLP 

            forge verify-contract --num-of-optimizations 800 --watch \
                --constructor-args $(cast abi-encode "constructor(address,address)" "0xfB3485c2e209A5cfBDC1447674256578f1A80eE3" "0xfB3485c2e209A5cfBDC1447674256578f1A80eE3") \
                --compiler-version v0.8.20+commit.a1b79de6 0x2612c7a5fDAF8Dea4f4D6C7A9da8e32A003706F6 src/mixins/BlastMagicLP.sol:BlastMagicLP \
                --verifier-url https://api.routescan.io/v2/network/testnet/evm/168587773/etherscan \
                -e verifyContract
        */
        implementation = MagicLP(
            deployUsingCreate3("MagicLPImplementation", MAGICLP_SALT, "BlastMagicLP.sol:BlastMagicLP", abi.encode(feeTo, tx.origin), 0)
        );

        BlastTokenRegistry blastTokenRegistry = BlastTokenRegistry(
            deployUsingCreate3(
                "BlastTokenRegistry",
                BLAST_TOKEN_REGISTRY_SALT,
                "BlastTokenRegistry.sol:BlastTokenRegistry",
                abi.encode(tx.origin),
                0
            )
        );

        if (!testing()) {
            // cast send --rpc-url https://sepolia.blast.io --private-key $PRIVATE_KEY 0x2612c7a5fDAF8Dea4f4D6C7A9da8e32A003706F6 "registerNativeYieldToken(address)" 0x4200000000000000000000000000000000000023
            blastTokenRegistry.registerNativeYieldToken(weth);

            // cast send --rpc-url https://sepolia.blast.io --private-key $PRIVATE_KEY 0x2612c7a5fDAF8Dea4f4D6C7A9da8e32A003706F6 "registerNativeYieldToken(address)" 0x4200000000000000000000000000000000000022
            blastTokenRegistry.registerNativeYieldToken(usdb);
        }

        // Maintainer fee model
        /*
            forge create --rpc-url https://sepolia.blast.io \
                --constructor-args 0 0xfB3485c2e209A5cfBDC1447674256578f1A80eE3 \
                --private-key $PRIVATE_KEY \
                src/auxiliary/FeeRateModel.sol:FeeRateModel

            forge verify-contract --num-of-optimizations 800 --watch \
                --constructor-args $(cast abi-encode "constructor(uint256,address)" "0" "0xfB3485c2e209A5cfBDC1447674256578f1A80eE3") \
                --compiler-version v0.8.20+commit.a1b79de6 0x86e761F620b7ac8Ea373e0463C8c3BCCE7bD385B src/auxiliary/FeeRateModel.sol:FeeRateModel \
                --verifier-url https://api.routescan.io/v2/network/testnet/evm/168587773/etherscan \
                -e verifyContract
        */
        feeRateModel = FeeRateModel(
            deployUsingCreate3("MaintainerFeeRateModel", MT_FEERATEMODEL_SALT, "FeeRateModel.sol:FeeRateModel", abi.encode(0, owner), 0)
        );

        // Registry
        /*
            forge create --rpc-url https://sepolia.blast.io \
                --constructor-args 0xfB3485c2e209A5cfBDC1447674256578f1A80eE3 \
                --private-key $PRIVATE_KEY \
                src/periphery/Registry.sol:Registry

            forge verify-contract --num-of-optimizations 800 --watch \
                --constructor-args $(cast abi-encode "constructor(address)" "0xfB3485c2e209A5cfBDC1447674256578f1A80eE3") \
                --compiler-version v0.8.20+commit.a1b79de6 0x38091Ad1880c21530D5b174b10D1ce24b40a584a src/periphery/Registry.sol:Registry \
                --verifier-url https://api.routescan.io/v2/network/testnet/evm/168587773/etherscan \
                -e verifyContract
        */
        registry = Registry(deployUsingCreate3("Registry", REGISTRY_SALT, "BlastWrappers.sol:Registry", abi.encode(tx.origin), 0));

        // Factory
        /*
            forge create --rpc-url https://sepolia.blast.io \
                --constructor-args 0x2612c7a5fDAF8Dea4f4D6C7A9da8e32A003706F6 0xfB3485c2e209A5cfBDC1447674256578f1A80eE3 0x86e761F620b7ac8Ea373e0463C8c3BCCE7bD385B 0x38091Ad1880c21530D5b174b10D1ce24b40a584a 0xfB3485c2e209A5cfBDC1447674256578f1A80eE3 \
                --private-key $PRIVATE_KEY \
                src/periphery/Factory.sol:Factory

            forge verify-contract --num-of-optimizations 800 --watch \
                --constructor-args $(cast abi-encode "constructor(address,address,address,address,address)" "0x2612c7a5fDAF8Dea4f4D6C7A9da8e32A003706F6" "0xfB3485c2e209A5cfBDC1447674256578f1A80eE3" "0x86e761F620b7ac8Ea373e0463C8c3BCCE7bD385B" "0x38091Ad1880c21530D5b174b10D1ce24b40a584a" "0xfB3485c2e209A5cfBDC1447674256578f1A80eE3") \
                --compiler-version v0.8.20+commit.a1b79de6 0xfB745B308a45EE475A96139a95273D96e69cb0bd src/periphery/Factory.sol:Factory \
                --verifier-url https://api.routescan.io/v2/network/testnet/evm/168587773/etherscan \
                -e verifyContract
        */
        factory = Factory(
            deployUsingCreate3(
                "Factory",
                FACTORY_SALT,
                "BlastWrappers.sol:Factory",
                abi.encode(implementation, maintainer, feeRateModel, registry, owner),
                0
            )
        );

        // Set Factory as Registry Operator
        // cast send --rpc-url https://sepolia.blast.io --private-key $PRIVATE_KEY 0x38091Ad1880c21530D5b174b10D1ce24b40a584a "setOperator(address,bool)" 0xfB745B308a45EE475A96139a95273D96e69cb0bd true
        if (!registry.operators(address(factory))) {
            registry.setOperator(address(factory), true);
        }

        // Router
        /*
            forge create --rpc-url https://sepolia.blast.io \
                --constructor-args 0x4200000000000000000000000000000000000023 0xfB3485c2e209A5cfBDC1447674256578f1A80eE3 0xfB3485c2e209A5cfBDC1447674256578f1A80eE3 \
                --private-key $PRIVATE_KEY \
                src/periphery/Router.sol:Router

            forge verify-contract --num-of-optimizations 800 --watch \
                --constructor-args $(cast abi-encode "constructor(address,address,address)" "0x4200000000000000000000000000000000000023" "0xfB3485c2e209A5cfBDC1447674256578f1A80eE3" "0xfB3485c2e209A5cfBDC1447674256578f1A80eE3") \
                --compiler-version v0.8.20+commit.a1b79de6 0x630FC1758De85C566Bdec1D75A894794E1819d7E src/periphery/Router.sol:Router \
                --verifier-url https://api.routescan.io/v2/network/testnet/evm/168587773/etherscan \
                -e verifyContract
        */
        router = Router(
            payable(
                deployUsingCreate3(
                    "Router",
                    ROUTER_SALT,
                    "BlastWrappers.sol:Router",
                    abi.encode(toolkit.getAddress(block.chainid, "weth"), feeTo, owner),
                    0
                )
            )
        );

        if (!testing()) {
            if (registry.owner() != owner) {
                registry.transferOwnership(owner);
            }
            if (blastTokenRegistry.owner() != owner) {
                blastTokenRegistry.transferOwnership(owner);
            }
            if (Owned(address(implementation)).owner() != owner) {
                Owned(address(implementation)).transferOwnership(owner);
            }
        }

        vm.stopBroadcast();
    }
}
