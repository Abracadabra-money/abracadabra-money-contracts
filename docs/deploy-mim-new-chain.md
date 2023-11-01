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
Update the test so it takes in account Scroll.

Update the test fork blocks
```shell
yarn task blocknumbers
```

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

## `tasks/lz/deployMIM.js`
Specify the chain to deploy MIM to. This is going to deploy using `MIMLayerZero` foundry script and configure min gas and trusted remote FROM scroll to other chains.
Once this is deployed, gnosis-safe transactions will need to be created to update the configurations to the other chains to allow scroll.

```javascript
const networks = ["scroll"];
```

```shell
yarn task lzDeployMIM --broadcast --verify
```

## Update `tasks/utils/lz.js`
```javascript
const tokenDeploymentNamePerNetwork = {
    ...
    "scroll": "Scroll_IndirectOFTV2",
};
```