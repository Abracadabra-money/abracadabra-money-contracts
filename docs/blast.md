# Testnet

## Add Operator on all testnet contract
```
ADDR=0x8764F421AB0C682b4Ba1d7e269C09187c1EfbFAF
RPC=https://rpc.ankr.com/blast_testnet_sepolia/64c52566bb4cb8f81c5a3608ad053385d6b0cfbcd01c1da2a49c87a4b214dfed
TARGETS="0xE5683f4bD410ea185692b5e6c9513Be6bf1017ec 0x25c27fb282c5D974e9B091d45F28BA5dE128e022 0x0eb13D9C49C31B57e896c1637766E9EcDC1989CD 0xBd73aA17Ce60B0e83d972aB1Fb32f7cE138Ca32A" 
for i in `echo $TARGETS`; do cast send --rpc-url $RPC --private-key $PRIVATE_KEY $i "setOperator(address,bool)" $ADDR true; done
```