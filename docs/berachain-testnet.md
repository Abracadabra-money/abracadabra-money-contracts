# Berachain Testnet

## Add Pool Event
Look at a transaction events after adding pool liquidity and locate the following events:

0x13f9c352919df1623a08e6d6d9eac5f774573896f09916d8fbc5d083095fc3b4: Topic 1 is the pool address
0x4568897068432b640861b304cacebddc8587a9f060d4bac0425c7311a90924af: Topic 1 is the token address

## MIM in MIMHONEY BEX cauldron
```
cast call --rpc-url https://artio.rpc.berachain.com/ 0x7a3b799E929C9bef403976405D8908fa92080449 "balanceOf(address,address)(uint256)" 0xB734c264F83E39Ef6EC200F99550779998cC812d 0x6aBD7831C3a00949dabCE4cCA74B4B6B327d6C26 
```

## Approve MIM on DegenBox
```
cast send --private-key $PRIVATE_KEY --rpc-url https://artio.rpc.berachain.com/ 0xB734c264F83E39Ef6EC200F99550779998cC812d "approve(address,uint256)" 0x7a3b799E929C9bef403976405D8908fa92080449 115792089237316195423570985008687907853269984665640564039457584007913129639935 
```

## TopUp
```
cast send --private-key $PRIVATE_KEY --rpc-url https://artio.rpc.berachain.com 0x7a3b799E929C9bef403976405D8908fa92080449 "deposit(address,address,address,uint256,uint256)" 0xB734c264F83E39Ef6EC200F99550779998cC812d 0xfB3485c2e209A5cfBDC1447674256578f1A80eE3 0x6aBD7831C3a00949dabCE4cCA74B4B6B327d6C26 100000000000000000000000 0
```