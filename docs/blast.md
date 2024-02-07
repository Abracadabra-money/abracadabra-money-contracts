# Testnet

## Mint 100_000 USDB
```
ADDR=0xfB3485c2e209A5cfBDC1447674256578f1A80eE3
cast send --rpc-url=https://rpc.sepolia.org \
  --private-key=$PRIVATE_KEY \
  0x7f11f79DEA8CE904ed0249a23930f2e59b43a385 \
  "mint(address,uint256)" $ADDR 10000000000000000000000 \ &&

cast call --rpc-url=https://rpc.sepolia.org \
  0x7f11f79DEA8CE904ed0249a23930f2e59b43a385 \
  "balanceOf(address) returns (uint256)" $ADDR \ &&

cast send --rpc-url=https://rpc.sepolia.org \
  --private-key=$PRIVATE_KEY \
  0x7f11f79DEA8CE904ed0249a23930f2e59b43a385 \
  "approve(address,uint256)" "0xc644cc19d2A9388b71dd1dEde07cFFC73237Dca8" 10000000000000000000000 \ &&

cast send --rpc-url=https://rpc.sepolia.org \
  --private-key=$PRIVATE_KEY \
  0xc644cc19d2A9388b71dd1dEde07cFFC73237Dca8 \
  "bridgeERC20(address localToken,address remoteToken,uint256 amount,uint32,bytes)" \
  "0x7f11f79DEA8CE904ed0249a23930f2e59b43a385" \
  "0x4200000000000000000000000000000000000022" \
  10000000000000000000000 500000 0x
```

## Mint 0.01 WETH
```
cast send --rpc-url=https://sepolia.blast.io \
    --private-key $PRIVATE_KEY 0x4200000000000000000000000000000000000023 "deposit()" --value 10000000000000000
```

## Deposit WETH to DegenBox Blast
```
ADDR=0xfB3485c2e209A5cfBDC1447674256578f1A80eE3
cast send --rpc-url=https://sepolia.blast.io \
    --private-key $PRIVATE_KEY 0x4200000000000000000000000000000000000023 "approve(address,uint)" 0x471EE749bA270eb4c1165B5AD95E614947f6fCeb 10000000000000000
cast send --rpc-url=https://sepolia.blast.io \
    --private-key $PRIVATE_KEY 0x471EE749bA270eb4c1165B5AD95E614947f6fCeb "deposit(address,address,address,uint,uint)" \
    0x4200000000000000000000000000000000000023 0xfB3485c2e209A5cfBDC1447674256578f1A80eE3 0xfB3485c2e209A5cfBDC1447674256578f1A80eE3 10000000000000000 0
```

## Harvest ETH yields
```
echo CLAIMABLE:
cast call --rpc-url=https://sepolia.blast.io 0x4300000000000000000000000000000000000002 "readClaimableYield(address)(uint)" 0x471EE749bA270eb4c1165B5AD95E614947f6fCeb

cast send --rpc-url=https://sepolia.blast.io \
    --private-key $PRIVATE_KEY 0x471EE749bA270eb4c1165B5AD95E614947f6fCeb "claimETHYields(uint)(uint)" \
    0x4200000000000000000000000000000000000023 115792089237316195423570985008687907853269984665640564039457584007913129639935
```

## Harvest WETH yields
```
echo ENABLED
cast call --rpc-url=https://sepolia.blast.io 0x471EE749bA270eb4c1165B5AD95E614947f6fCeb "enabledTokens(address)(bool)" 0x4200000000000000000000000000000000000023

echo CLAIMABLE:
cast call --rpc-url=https://sepolia.blast.io 0x4200000000000000000000000000000000000023 "getClaimableAmount(address)(uint)" 0x471EE749bA270eb4c1165B5AD95E614947f6fCeb

cast send --rpc-url=https://sepolia.blast.io \
    --private-key $PRIVATE_KEY 0x471EE749bA270eb4c1165B5AD95E614947f6fCeb "claimTokenYields(address,uint)(uint)" \
    0x4200000000000000000000000000000000000023 115792089237316195423570985008687907853269984665640564039457584007913129639935
```