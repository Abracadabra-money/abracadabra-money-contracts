// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {IBlastBox} from "/blast/interfaces/IBlastBox.sol";
import {FeeCollectable} from "mixins/FeeCollectable.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {ProxyOracle} from "oracles/ProxyOracle.sol";
import {FixedPriceOracle} from "oracles/FixedPriceOracle.sol";
import {ICauldronV4} from "interfaces/ICauldronV4.sol";
import {CauldronDeployLib} from "utils/CauldronDeployLib.sol";
import {IBentoBoxV1} from "interfaces/IBentoBoxV1.sol";
import {IOracle} from "interfaces/IOracle.sol";
import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {BlastTokenRegistry} from "/blast/BlastTokenRegistry.sol";

contract BlastScript is BaseScript {
    string public constant REV = "1.0.0";
    bytes32 BLAST_TOKEN_REGISTRY_SALT = keccak256(bytes(string.concat("BLAST_TOKEN_REGISTRY_", REV)));
    bytes32 BLAST_GOVERNOR_SALT = keccak256(bytes(string.concat("BLAST_GOVERNOR_", REV)));

    function deploy() public returns (address blastBox) {
        address feeTo = 0xfB3485c2e209A5cfBDC1447674256578f1A80eE3; // TODO: replace for prod

        vm.startBroadcast();

        (address blastGovernor, address blastTokenRegistry) = deployPrerequisites(tx.origin);

        /*
            forge create --rpc-url https://sepolia.blast.io \
                --constructor-args 0x4200000000000000000000000000000000000023 0x70EF66237D36c99802F026E1A5508Be87cc32992 0xfB3485c2e209A5cfBDC1447674256578f1A80eE3  \
                --private-key $PRIVATE_KEY \
                src/mixins/DegenBoxBlast.sol:DegenBoxBlast

            forge verify-contract --num-of-optimizations 400 --watch \
                --constructor-args $(cast abi-encode "constructor(address,address,address)" "0x4200000000000000000000000000000000000023" "0x70EF66237D36c99802F026E1A5508Be87cc32992" "0xfB3485c2e209A5cfBDC1447674256578f1A80eE3") \
                --compiler-version v0.8.20+commit.a1b79de6 0x04146736FEF83A25e39834a972cf6A5C011ACEad src/mixins/DegenBoxBlast.sol:DegenBoxBlast \
                --verifier-url https://api.routescan.io/v2/network/testnet/evm/168587773/etherscan \
                -e verifyContract
        */
        blastBox = deploy("BlastBox", "BlastBox.sol:BlastBox", abi.encode(toolkit.getAddress(ChainId.Blast, "weth"), blastTokenRegistry, feeTo));

        /*
            forge create --rpc-url https://sepolia.blast.io \
                --constructor-args 0xfB3485c2e209A5cfBDC1447674256578f1A80eE3 "Magic Internet Money" "MIM" 18  \
                --private-key $PRIVATE_KEY \
                src/tokens/MintableBurnableERC20.sol:MintableBurnableERC20 

            forge verify-contract --num-of-optimizations 400 --watch \
                --constructor-args $(cast abi-encode "constructor(address,string,string,uint8)" "0xfB3485c2e209A5cfBDC1447674256578f1A80eE3" "Magic Internet Money" "MIM" 18) \
                --compiler-version v0.8.20+commit.a1b79de6 0x1E217d3cA2a19f2cB0F9f12a65b40f335286758E src/tokens/MintableBurnableERC20.sol:MintableBurnableERC20 \
                --verifier-url https://api.routescan.io/v2/network/testnet/evm/168587773/etherscan \
                -e verifyContract
        */
        address mim = address(
            deploy("MIM", "MintableBurnableERC20.sol:MintableBurnableERC20", abi.encode(tx.origin, "Magic Internet Money", "MIM", 18))
        );

        /*
            forge create --rpc-url https://sepolia.blast.io \
                --constructor-args 0x04146736FEF83A25e39834a972cf6A5C011ACEad 0x1E217d3cA2a19f2cB0F9f12a65b40f335286758E \
                --private-key $PRIVATE_KEY \
                src/cauldrons/CauldronV4.sol:CauldronV4 

            forge verify-contract --num-of-optimizations 400 --watch \
                --constructor-args $(cast abi-encode "constructor(address,address)" "0x04146736FEF83A25e39834a972cf6A5C011ACEad" "0x1E217d3cA2a19f2cB0F9f12a65b40f335286758E") \
                --compiler-version v0.8.20+commit.a1b79de6 0x76DA31D7C9CbEAE102aff34D3398bC450c8374c1 src/cauldrons/CauldronV4.sol:CauldronV4 \
                --verifier-url https://api.routescan.io/v2/network/testnet/evm/168587773/etherscan \
                -e verifyContract
        */
        address mc = deploy("CauldronV4", "BlastWrappers.sol:BlastCauldronV4", abi.encode(blastBox, mim, blastGovernor));

        /*
            forge create --rpc-url https://sepolia.blast.io \
                --private-key $PRIVATE_KEY \
                src/oracles/ProxyOracle.sol:ProxyOracle 

            forge verify-contract --num-of-optimizations 400 --watch \
                --compiler-version v0.8.20+commit.a1b79de6 0x3de60fF9031F9C8E5D361e4D1611042A050E4198 src/oracles/ProxyOracle.sol:ProxyOracle  \
                --verifier-url https://api.routescan.io/v2/network/testnet/evm/168587773/etherscan \
                -e verifyContract
        */
        ProxyOracle oracle = ProxyOracle(deploy("ProxyOracle", "ProxyOracle.sol:ProxyOracle", ""));

        /*
            forge create --rpc-url https://sepolia.blast.io \
                --constructor-args "MIM/USDD" 1000000000000000000 18 \
                --private-key $PRIVATE_KEY \
                src/oracles/FixedPriceOracle.sol:FixedPriceOracle 

            forge verify-contract --num-of-optimizations 400 --watch \
                --constructor-args $(cast abi-encode "constructor(string,uint,uint)" "MIM/USDB" 1000000000000000000 18) \
                --compiler-version v0.8.20+commit.a1b79de6 0xa02DE9526b17b3087C83340A0De544dcf9d034Bb src/oracles/FixedPriceOracle.sol:FixedPriceOracle \
                --verifier-url https://api.routescan.io/v2/network/testnet/evm/168587773/etherscan \
                -e verifyContract
        */
        FixedPriceOracle fixedPriceOracle = FixedPriceOracle(
            deploy("MimUsdb_Oracle_Impl", "FixedPriceOracle.sol:FixedPriceOracle", abi.encode("MIM/USDB", 1e18, 18))
        );

        oracle.changeOracleImplementation(fixedPriceOracle);

        /* ICauldronV4 cauldron = CauldronDeployLib.deployCauldronV4(
            "CauldronV4_MimUsdbLP",
            IBentoBoxV1(toolkit.getAddress(ChainId.Blast, "degenBox")),
            toolkit.getAddress(ChainId.Blast, "cauldronV4"),
            IERC20(toolkit.getAddress(ChainId.Blast, "TODO")),
            IOracle(address(0x3de60fF9031F9C8E5D361e4D1611042A050E4198)),
            "",
            9000, // 90% ltv
            500, // 5% interests
            100, // 1% opening
            600 // 6% liquidation
        );*/

        if (!testing()) {
            IBlastBox(blastBox).setTokenEnabled(toolkit.getAddress(ChainId.Blast, "weth"), true);
            IBlastBox(blastBox).setTokenEnabled(toolkit.getAddress(ChainId.Blast, "usdb"), true);
            FeeCollectable(blastBox).setFeeParameters(tx.origin, 10_000);

            //if (Owned(mim).owner() != safe) {
            //    Owned(mim).transferOwnership(safe);
            //}
        }
        vm.stopBroadcast();
    }

    function deployPrerequisites(address owner) public returns (address blastGovernor, address blastTokenRegistry) {
        /*
            forge create --rpc-url https://sepolia.blast.io \
                --constructor-args 0xfB3485c2e209A5cfBDC1447674256578f1A80eE3 \
                --private-key $PRIVATE_KEY \
                src/blast/BlastGovernor.sol:BlastGovernor 

            forge verify-contract --num-of-optimizations 800 --watch \
                --constructor-args $(cast abi-encode "constructor(address)" "0xfB3485c2e209A5cfBDC1447674256578f1A80eE3") \
                --compiler-version v0.8.20+commit.a1b79de6 aaabbbccc src/blast/BlastGovernor.sol:BlastGovernor \
                --verifier-url https://api.routescan.io/v2/network/testnet/evm/168587773/etherscan \
                -e verifyContract
        */
        blastGovernor = deployUsingCreate3(
            "BlastGovernor",
            BLAST_GOVERNOR_SALT,
            "BlastGovernor.sol:BlastGovernor",
            abi.encode(tx.origin),
            0
        );

        /*
            forge create --rpc-url https://sepolia.blast.io \
                --constructor-args 0xfB3485c2e209A5cfBDC1447674256578f1A80eE3 \
                --private-key $PRIVATE_KEY \
                src/blast/BlastTokenRegistry.sol:BlastTokenRegistry 

            forge verify-contract --num-of-optimizations 800 --watch \
                --constructor-args $(cast abi-encode "constructor(address)" "0xfB3485c2e209A5cfBDC1447674256578f1A80eE3") \
                --compiler-version v0.8.20+commit.a1b79de6 aaabbbccc src/blast/BlastTokenRegistry.sol:BlastTokenRegistry \
                --verifier-url https://api.routescan.io/v2/network/testnet/evm/168587773/etherscan \
                -e verifyContract
        */
        blastTokenRegistry = deployUsingCreate3(
            "BlastTokenRegistry",
            BLAST_TOKEN_REGISTRY_SALT,
            "BlastTokenRegistry.sol:BlastTokenRegistry",
            abi.encode(tx.origin),
            0
        );

        if (!testing()) {
            // cast send --rpc-url https://sepolia.blast.io --private-key $PRIVATE_KEY 0x2612c7a5fDAF8Dea4f4D6C7A9da8e32A003706F6 "registerNativeYieldToken(address)" 0x4200000000000000000000000000000000000023
            BlastTokenRegistry(blastTokenRegistry).registerNativeYieldToken(toolkit.getAddress(block.chainid, "weth"));

            // cast send --rpc-url https://sepolia.blast.io --private-key $PRIVATE_KEY 0x2612c7a5fDAF8Dea4f4D6C7A9da8e32A003706F6 "registerNativeYieldToken(address)" 0x4200000000000000000000000000000000000022
            BlastTokenRegistry(blastTokenRegistry).registerNativeYieldToken(toolkit.getAddress(block.chainid, "usdb"));

            if (BlastTokenRegistry(blastTokenRegistry).owner() != owner) {
                BlastTokenRegistry(blastTokenRegistry).transferOwnership(owner);
            }
        }
    }
}
