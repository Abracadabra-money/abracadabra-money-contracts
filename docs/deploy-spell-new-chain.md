# How to deploy SPELL on a new chain

> This is using arbitrum as an example.

## `tasks/lz/deployOFTV2.js`
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
yarn task lzDeployOFTV2 --token spell --broadcast --verify
```

> Ensure all contracts are correctly verified.

## Update `tasks/utils/lz.js`
Update all configurations to include scroll configurations.

```shell
yarn task lzDeployPrecrime --broadcast --verify
```

## Transfer OFTV2 ownership
```shell
cast send --rpc-url https://1rpc.io/arb --account deployer [oftv2-address] "transferOwnership(address)" [multisig-address]
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