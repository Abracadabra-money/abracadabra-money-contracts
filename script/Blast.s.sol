// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {IDegenBoxBlast} from "mixins/DegenBoxBlast.sol";
import {FeeCollectable} from "mixins/FeeCollectable.sol";

contract BlastScript is BaseScript {
    function deploy() public returns (address blastBox) {
        vm.startBroadcast();

        /*
            forge create --rpc-url https://sepolia.blast.io \
                --constructor-args 0x4200000000000000000000000000000000000023  \
                --private-key $PRIVATE_KEY \
                src/mixins/DegenBoxBlast.sol:DegenBoxBlast

            forge verify-contract --chain-id 1 --num-of-optimizations 400 --watch \
                --constructor-args $(cast abi-encode "constructor(address)" "0x4200000000000000000000000000000000000023") \
                --compiler-version v0.8.20+commit.a1b79de6 0x7a3b799E929C9bef403976405D8908fa92080449  src/mixins/DegenBoxBlast.sol:DegenBoxBlast \
                --verifier-url https://api.routescan.io/v2/network/testnet/evm/168587773/etherscan \
                -e verifyContract
        */
        blastBox = deploy("DegenBoxBlast", "DegenBoxBlast.sol:DegenBoxBlast", abi.encode(toolkit.getAddress(ChainId.Blast, "weth")));

        if (!testing()) {
            IDegenBoxBlast(blastBox).setTokenEnabled(toolkit.getAddress(ChainId.Blast, "weth"), true, true);
            IDegenBoxBlast(blastBox).setTokenEnabled(toolkit.getAddress(ChainId.Blast, "usdb"), true, true);
            FeeCollectable(blastBox).setFeeParameters(tx.origin, 100);
        }
        vm.stopBroadcast();
    }
}
