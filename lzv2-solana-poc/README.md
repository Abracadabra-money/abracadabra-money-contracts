# POC of Cross Chain Token Transfer between EVM and Solana

Implement cross chain token transfer functionality using layerzero v2 oft (EVM <-> Solana).

### Getting Started
Need to prepare several test wallets on <code>Arbitrum Sepolia</code> and <code>Solana Testnet</code> and deposit native tokens for contract deployment and test.

```
EVM_ADMIN_PRIVATE_KEY=
EVM_ADMIN_PUB_KEY=
EVM_USER_PRIVATE_KEY=
EVM_USER_PUB_KEY=

SOLANA_ADMIN_PRIVATE_KEY=
SOLANA_ADMIN_PUB_KEY=
SOLANA_USER_PRIVATE_KEY=
SOLANA_USER_PUB_KEY=
```


### Prerequisites
```
Yarn
Rust
Solana CLI
Anchor CLI
```

### Install & Build
##### Inside EVM folder:
```
yarn install
hardhat compile
```
##### Inside Solana folder:
```
yarn install
anchor build
```
Replace programId of lzv2oft program and build again.
```
solana-keygen pubkey ./target/deploy/lzv2oft-keypair.json
```
The program id will be provided, then replace it [here](https://github.com/RustChainBuilder/lzv2-oft-poc/blob/master/Solana/programs/lzv2oft/src/lib.rs#L22), and build again
```
anchor build
```

### Deploy
##### Inside EVM folder:
```
hardhat deploy
```
After contract deployment to the arbitrum sepolia, deployed contract address will be provided.
Need to set <code>.env</code> variable.
```
ARBITRUM_SEPOLIA_OFT_ADDRESS= <deployed contract address>
```

##### Insided Solana folder:
Check local config and set url as <code>testnet</code> if it's not, also check testnet balance.
```
solana config get
solana balance
```
If all are fine, then deploy lzv2oft program.
```
solana program deploy ./target/deploy/lzv2oft.so
```
After contract deployment to the solana testnet, <code>.env</code> variable should be set.
```
SOLANA_TESTNET_CONTRACT_ADDRESS= <deployed program id>
```

### Test
#### Pre configuration setting on both EVM and Solana
##### Inside Solana folder:
```
yarn run mintToken
```
We will mint 100 Solana OFT token to <code>SOLANA_USER_PUB_KEY</code>, and you can check on Phantom.
Token mint address should be provided, and need to update <code>.env</code> variable.
```
SOLANA_SPL_TOKEN_ADDRESS= <token mint pubkey>
```

```
yarn run initConfig
```
OFT pda should be provided after running above command, and need to update <code>.env</code> variable.
```
SOLANA_TESTNET_OFT_ADDRESS= <oft pda pubkey>
```

And we need to set peer on the solana side.
```
yarn run setPeer
```

##### Inside EVM folder:
```
yarn run mintToken
```
We will mint EVM OFT token to <code>EVM_USER_PUB_KEY</code>, and you can check on Metamask.

```
yarn run setPeer
```

#### Send Token
##### Inside Solana folder:
```
yarn run send
```
##### Inside Evm folder:
```
yarn run send
```

Transaction hash should be provided after running command so that you can check it on block explorer, but also you can check token amount on wallets.

### Block explorer to inspect trasactions
EVM: https://sepolia.arbiscan.io/
Solana: https://solscan.io/
Layerzero: https://testnet.layerzeroscan.com/


