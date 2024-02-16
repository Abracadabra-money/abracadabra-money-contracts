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

contract BlastScript is BaseScript {
    function deploy() public returns (address blastBox) {
        vm.startBroadcast();

        /*
            forge create --rpc-url https://sepolia.blast.io \
                --constructor-args 0x4200000000000000000000000000000000000023  \
                --private-key $PRIVATE_KEY \
                src/mixins/DegenBoxBlast.sol:DegenBoxBlast

            forge verify-contract --num-of-optimizations 400 --watch \
                --constructor-args $(cast abi-encode "constructor(address)" "0x4200000000000000000000000000000000000023") \
                --compiler-version v0.8.20+commit.a1b79de6 0x04146736FEF83A25e39834a972cf6A5C011ACEad src/mixins/DegenBoxBlast.sol:DegenBoxBlast \
                --verifier-url https://api.routescan.io/v2/network/testnet/evm/168587773/etherscan \
                -e verifyContract
        */
        blastBox = deploy("BlastBox", "BlastBox.sol:BlastBox", abi.encode(toolkit.getAddress(ChainId.Blast, "weth")));

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
        address mc = deploy("CauldronV4", "BlastCauldronV4.sol:BlastCauldronV4", abi.encode(blastBox, mim));

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
            IBlastBox(blastBox).setTokenEnabled(toolkit.getAddress(ChainId.Blast, "weth"), true, true);
            IBlastBox(blastBox).setTokenEnabled(toolkit.getAddress(ChainId.Blast, "usdb"), true, true);
            FeeCollectable(blastBox).setFeeParameters(tx.origin, 10_000);

            //if (Owned(mim).owner() != safe) {
            //    Owned(mim).transferOwnership(safe);
            //}
        }
        vm.stopBroadcast();
    }
}
