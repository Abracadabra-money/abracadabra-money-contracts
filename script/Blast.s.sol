// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {IDegenBoxBlast} from "mixins/DegenBoxBlast.sol";
import {FeeCollectable} from "mixins/FeeCollectable.sol";
import {Owned} from "solmate/auth/Owned.sol";

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
                --compiler-version v0.8.20+commit.a1b79de6 0x471EE749bA270eb4c1165B5AD95E614947f6fCeb src/mixins/DegenBoxBlast.sol:DegenBoxBlast \
                --verifier-url https://api.routescan.io/v2/network/testnet/evm/168587773/etherscan \
                -e verifyContract
        */
        blastBox = deploy("DegenBoxBlast", "DegenBoxBlast.sol:DegenBoxBlast", abi.encode(toolkit.getAddress(ChainId.Blast, "weth")));

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

        if (!testing()) {
            IDegenBoxBlast(blastBox).setTokenEnabled(toolkit.getAddress(ChainId.Blast, "weth"), true, true);
            IDegenBoxBlast(blastBox).setTokenEnabled(toolkit.getAddress(ChainId.Blast, "usdb"), true, true);
            FeeCollectable(blastBox).setFeeParameters(tx.origin, 10_000);

            //if (Owned(mim).owner() != safe) {
            //    Owned(mim).transferOwnership(safe);
            //}
        }
        vm.stopBroadcast();
    }
}
