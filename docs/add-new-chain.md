# How to add a new chain to the repo

> Scroll chain is used as an example.

## `.env.defaults`
Add an environment variable for the RPC_URL. The rpc should be an **archive node**.
Leave the etherscan_key empty and override it in `.env`

```
SCROLL_RPC_URL=https://rpc.scroll.io
SCROLL_ETHERSCAN_KEY=
```

## `hardhat.config.js`
See https://layerzero.gitbook.io/docs/technical-reference/mainnet/supported-chain-ids for a list of support layer zero chain ids.

1. add the chain to the `networks` section.
```javascript
    scroll: {
      url: process.env.SCROLL_RPC_URL,
      api_key: process.env.SCROLL_ETHERSCAN_KEY,
      chainId: 534352,
      lzChainId: 214,
      accounts
    },
```

## `utils/Toolkit.sol`
```solidity
library ChainId {
    ...
    uint256 internal constant Scroll = 534352;
}

library LayerZeroChainId {
    ...
    uint16 internal constant Scroll = 214;
}
uint[] public chains = [
    ...
    ChainId.Scroll
];
chainIdToName[ChainId.Scroll] = "Scroll";
chainIdToLzChainId[ChainId.Scroll] = LayerZeroChainId.Scroll;
```

## JSON config
Add `config/scroll.json` with the basic common use addresses.

```json
{
    "addresses": [
        { "key": "weth", "value": "0x5300000000000000000000000000000000000004" },
        { "key": "safe.ops", "value": "0x71C3d2bBB0178713E7aC828f06187A70d7BC2822" },
        { "key": "LZendpoint", "value": "0xb6319cC6c8c27A8F5dAF0dD3DF91EA35C4720dd7" }
    ],
    "cauldrons": [
        
    ],
    "pairCodeHashes": [

    ]
}
```

## ethers-rs
Sometime a chain is still not yet supported in ethers-rs. https://github.com/gakonst/ethers-rs
Create a new PR to add it.

Example with linea:
https://github.com/gakonst/ethers-rs/commit/49be9dc6a5642d8d4eb5254b7540dd20a2689735
