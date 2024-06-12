// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";

/*
    How to use:

    yarn deploy-multichain --script BlastMagicLPBridge blast arbitrum --no-confirm && \
    cp -R deployments/42161/Arbitrum_BlastMagicLPBridge.json deployments/81457/Blast_BlastMagicLPBridge.json && \
    yarn task verify --network blast --deployment Blast_BlastMagicLPBridge --artifact src/migrations/BlastMagicLPBridge.sol:BlastMagicLPBridge

    Test:
    //export OLD="0x9bcEb58d0AdC360eFDfDb1AF3E93d733EfBE702C"
    //cast-arbitrum send --private-key $PRIVATE_KEY $OLD "recover(address,address,uint)" 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9 $C 24000000

    export C="0xE62BdD21bD2bF3E40582efFBbf52e0f3a80e1bEf"
    cast-blast send --private-key $PRIVATE_KEY 0x163B234120aaE59b46b228d8D88f5Bc02e9baeEa "approve(address,uint)" $C 100000000000000000000
    cast-blast send --private-key $PRIVATE_KEY $C "setMerkleRoot(bytes32,string)" "0x0e0cdcf0924deb002fcb06b51e9c767afbefad36e4c3674a46e25609a18e6f8d" "none"
    cast-blast send --private-key $PRIVATE_KEY $C "setAllowedAmount(address,uint256,bytes32[])" 0xfB3485c2e209A5cfBDC1447674256578f1A80eE3 3000000000000000000 "[0xccf114a0823e60bb259133b44061bfb5408e85680aaff32067e5ce404f552d66]"
    cast-blast send --private-key $PRIVATE_KEY $C --value 0.0007ether "bridge(uint,uint,uint,(uint128,uint128,uint128,uint128))(uint,uint)" 1000000000000000000 0 0 "(460747124347691,100000,176144732780200,100000)"
*/
contract BlastMagicLPBridgeScript is BaseScript {
    bytes32 constant SALT = keccak256(bytes("BlastMagicLPBridge-1718122995"));

    function deploy() public {
        vm.startBroadcast();
        deployUsingCreate3("BlastMagicLPBridge", SALT, "BlastMagicLPBridge.sol:BlastMagicLPBridge", abi.encode(tx.origin));
        vm.stopBroadcast();
    }
}
