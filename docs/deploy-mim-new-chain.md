# How to deploy MIM on a new chain

> Follow `add-new-chain.md` to add the chain support to the repository.
> This is using scroll as an example.

## Update `script/MIMLayerZero.s.sol`
```solidity
_chainUsingNativeFeeCollecting[ChainId.Scroll] = true;
...
fixedFees[534352] = 550000000000000; // default ETH fee
```

## Update `test/MIMLayerZero.t.sol`
Update the test fork blocks using this command.
```shell
yarn task blocknumbers
```

Update the test so it takes in account Scroll.
```solidity
uint[] chains = [
    ...
    ChainId.Scroll
];

uint[] lzChains = [
    ...
    LayerZeroChainId.Scroll
];

mimWhale[ChainId.Scroll] = address(0);
```

## Run tests
Verify that all tests pass. If there's logs about paths no being opened, it's required to ask LayerZero to open them.
```shell
yarn test --match-path test/MIMLayerZero.t.sol -vv
```

## `tasks/lz/deployMIM.js`
Specify the chain to deploy MIM to. This is going to deploy using `MIMLayerZero` foundry script and configure min gas and trusted remote FROM scroll to other chains.
Once this is deployed, gnosis-safe transactions will need to be created to update the configurations to the other chains to allow scroll.

```javascript
const networks = ["scroll"];
```

## `tasks/lz/deployPrecrime.js`
Specify the chain to deploy Precrime for.
```javascript
const networks = ["scroll"];
```

```shell
yarn task lzDeployMIM --broadcast --verify
```

## Update `config/scroll.json`
add `oftv2` entry. The address can be found inside `deployments/534352/Scroll_IndirectOFTV2.json`
```json
 { "key": "oftv2", "value": "0x52B2773FB2f69d565C651d364f0AA95eBED097E4" }
```

> Ensure all contracts are correctly verified.

## Update `tasks/utils/lz.js`
Update all configurations to include scroll configurations.

```shell
yarn task lzDeployPrecrime --broadcast --verify
```

## Transfer OFTV2 ownership
```shell
cast send --rpc-url https://rpc.scroll.io --private-key $PRIVATE_KEY [oftv2-address] "transferOwnership(address)" [multisig-address]
```

## Schedule Multsig Transactions
```shell
yarn task lzGnosisConfigure --from all --to scroll --set-remote-path --set-min-gas --set-precrime
```

All gnosis transaction batches will be output in `out/`. `scroll-batch.json` can be ignored since this has already been done when deploying.

## (Optional) Set FeeHandler Oracle
By default, the fee handler uses a fixed native token price.

```
setAggregator(IAggregator agg) // must be a compatible interface supporting `latestAnswer()`
```