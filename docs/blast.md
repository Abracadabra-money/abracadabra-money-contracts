# Testnet

## Add Operator on all testnet contract
```sh
ADDR=0x8764F421AB0C682b4Ba1d7e269C09187c1EfbFAF
RPC=https://rpc.ankr.com/blast_testnet_sepolia/64c52566bb4cb8f81c5a3608ad053385d6b0cfbcd01c1da2a49c87a4b214dfed
MAGICLP_IMPL="0x8176C5408c5DeC30149232A74Ef8873379b59982."
GOVERNOR="0x25c27fb282c5D974e9B091d45F28BA5dE128e022"
MIM="0x0eb13D9C49C31B57e896c1637766E9EcDC1989CD"
cast send --rpc-url $RPC --private-key $PRIVATE_KEY $i "setOperator(address,bool)" $MAGICLP_IMPL true
cast send --rpc-url $RPC --private-key $PRIVATE_KEY $i "setOperator(address,bool)" $GOVERNOR true
cast send --rpc-url $RPC --private-key $PRIVATE_KEY $i "setOperator(address,bool)" $MIM true
```

## Claiming gas rewards
```sh
RPC=https://rpc.ankr.com/blast_testnet_sepolia/64c52566bb4cb8f81c5a3608ad053385d6b0cfbcd01c1da2a49c87a4b214dfed
GOVERNOR="0x25c27fb282c5D974e9B091d45F28BA5dE128e022"
CAULDRONV4_MC="0x87A5bF86D6C96775d926F43700c0fD99EE0c2E82"
FACTORY="0x9Ca03FeBDE38c2C8A2E8F3d74E23a58192Ca921d"
ROUTER="0x15f57fbCB7A443aC6022e051a46cAE19491bC298"

cast send --rpc-url $RPC --private-key $PRIVATE_KEY $GOVERNOR "claim(address)" $CAULDRONV4_MC
cast send --rpc-url $RPC --private-key $PRIVATE_KEY $GOVERNOR "claim(address)" $FACTORY
cast send --rpc-url $RPC --private-key $PRIVATE_KEY $GOVERNOR "claim(address)" $ROUTER

cast send --rpc-url $RPC --private-key $PRIVATE_KEY 0x8176C5408c5DeC30149232A74Ef8873379b59982 "claimYields()" 
```

## Create MIMSwap LP, add liquidity, swap, remove liquidity
```sh
SENDER=$(cast w a $PRIVATE_KEY)
WETH=0x4200000000000000000000000000000000000023
MIM=0x0eb13D9C49C31B57e896c1637766E9EcDC1989CD
FACTORY=0x9Ca03FeBDE38c2C8A2E8F3d74E23a58192Ca921d
REGISTRY=0xBd73aA17Ce60B0e83d972aB1Fb32f7cE138Ca32A
ROUTER=0x15f57fbCB7A443aC6022e051a46cAE19491bC298
GOVERNOR=0x25c27fb282c5D974e9B091d45F28BA5dE128e022

echo WETH-MIM pool count:
cast call --rpc-url=https://sepolia.blast.io $REGISTRY "count(address,address)(uint256)" $WETH $MIM
cast call --rpc-url=https://sepolia.blast.io $REGISTRY "count(address,address)(uint256)" $MIM $WETH

echo Create pool:
LP=$(cast call --private-key $PRIVATE_KEY --rpc-url=https://sepolia.blast.io $FACTORY "create(address,address,uint256,uint256,uint256)(address)" $MIM $WETH 400000000000000 1000000000000000000 500000000000000)
cast send --private-key $PRIVATE_KEY --rpc-url=https://sepolia.blast.io $FACTORY "create(address,address,uint256,uint256,uint256)(address)" $MIM $WETH 400000000000000 1000000000000000000 500000000000000
echo $LP

echo Initial add liquidity:
cast call --rpc-url=https://sepolia.blast.io $ROUTER "previewAddLiquidity(address,uint256,uint256)(uint256,uint256,uint256)" $LP 10000000000000000 10000000000000000
cast send --private-key $PRIVATE_KEY --rpc-url=https://sepolia.blast.io --value 0.01ether $ROUTER "addLiquidityETH(address,address,address,uint256,uint256,uint256)(uint256,uint256,uint256)" $LP $SENDER $SENDER 10000000000000000 9999999999998999 $(($(date +%s)+3600))
cast call --rpc-url=https://sepolia.blast.io $LP "balanceOf(address)(uint256)" $SENDER

echo Swap ETH:
cast send --private-key $PRIVATE_KEY --rpc-url=https://sepolia.blast.io $ROUTER "sellQuoteETHForTokens(address,address,uint256,uint256)(uint256)" $LP $SENDER $SENDER 10000000000000000 10000000000000000 $(($(date +%s)+3600))
```
