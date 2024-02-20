# Testnet

## Add Operator on all testnet contract
```
ADDR=0x8764F421AB0C682b4Ba1d7e269C09187c1EfbFAF
RPC=https://rpc.ankr.com/blast_testnet_sepolia/64c52566bb4cb8f81c5a3608ad053385d6b0cfbcd01c1da2a49c87a4b214dfed
MAGICLP_IMPL="0xE5683f4bD410ea185692b5e6c9513Be6bf1017ec"
GOVERNOR="0x25c27fb282c5D974e9B091d45F28BA5dE128e022"
MIM="0x0eb13D9C49C31B57e896c1637766E9EcDC1989CD"
REGISTRY="0xBd73aA17Ce60B0e83d972aB1Fb32f7cE138Ca32A"
cast send --rpc-url $RPC --private-key $PRIVATE_KEY $i "setOperator(address,bool)" $MAGICLP_IMPL true
cast send --rpc-url $RPC --private-key $PRIVATE_KEY $i "setOperator(address,bool)" $GOVERNOR true
cast send --rpc-url $RPC --private-key $PRIVATE_KEY $i "setOperator(address,bool)" $MIM **true**
cast send --rpc-url $RPC --private-key $PRIVATE_KEY $i "setOperator(address,bool)" $REGISTRY true
```

## Claiming gas rewards
```
RPC=https://rpc.ankr.com/blast_testnet_sepolia/64c52566bb4cb8f81c5a3608ad053385d6b0cfbcd01c1da2a49c87a4b214dfed
GOVERNOR="0x25c27fb282c5D974e9B091d45F28BA5dE128e022"
CAULDRONV4_MC="0x87A5bF86D6C96775d926F43700c0fD99EE0c2E82"
REGISTRY="0xBd73aA17Ce60B0e83d972aB1Fb32f7cE138Ca32A"
FACTORY="0x9Ca03FeBDE38c2C8A2E8F3d74E23a58192Ca921d"
ROUTER="0x15f57fbCB7A443aC6022e051a46cAE19491bC298"

cast send --rpc-url $RPC --private-key $PRIVATE_KEY $GOVERNOR "claim(address)" $CAULDRONV4_MC
cast send --rpc-url $RPC --private-key $PRIVATE_KEY $GOVERNOR "claim(address)" $REGISTRY
cast send --rpc-url $RPC --private-key $PRIVATE_KEY $GOVERNOR "claim(address)" $FACTORY
cast send --rpc-url $RPC --private-key $PRIVATE_KEY $GOVERNOR "claim(address)" $ROUTER
```