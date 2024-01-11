# Berachain Testnet

## MIM in MIMHONEY BEX cauldron
```
cast call --rpc-url https://rpc.berachain-internal.com 0xBb7211F6591cB763DE27a1205d4678E3616409D5 "balanceOf(address,address)" 0x2ed641367f16f9783666409be7d083c8c49cbec2 0xD3d8dbB6EE0A3620F584814C9a0A1201b1E879D8 
```

## Approve MIM on DegenBox
```
cast send --private-key $PRIVATE_KEY --rpc-url https://rpc.berachain-internal.com 0x2ed641367f16f9783666409be7d083c8c49cbec2 "approve(address,uint256)" 0xBb7211F6591cB763DE27a1205d4678E3616409D5 115792089237316195423570985008687907853269984665640564039457584007913129639935 
```

## TopUp
```
cast send --private-key $PRIVATE_KEY --rpc-url https://rpc.berachain-internal.com 0xBb7211F6591cB763DE27a1205d4678E3616409D5 "deposit(address,address,address,uint256,uint256)" 0x2ed641367f16f9783666409be7d083c8c49cbec2 0xfB3485c2e209A5cfBDC1447674256578f1A80eE3 0xD3d8dbB6EE0A3620F584814C9a0A1201b1E879D8 100000000000000000000000 0
```