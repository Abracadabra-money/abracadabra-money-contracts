# Abracadabra Money Contracts

## Prerequisites
- Foundry
- Rust/Cargo
- Yarn
- Linux / MacOS / WSL 2

## Commit Style
`<emoji><space><Title>`

| Type             | Emoji |
|------------------|-------|
| readme/docs      | 📝 |
| new feature      | ✨ |
| refactor/cleanup | ♻️ |
| nit              | 🥢 |
| security fix     | 🔒 |
| optimization     | ⚡️ |
| configuration    | 👷‍♂️ |
| events           | 🔊 |
| bug fix          | 🐞 |
| tooling          | 🔧 |
| deployments      | 🚀 |

## Getting Started
Initialize
```sh
yarn
```

Make a copy of `.env.defaults` to `.env` and set the desired parameters. This file is git ignored.

Build and Test.

```sh
yarn
yarn build
yarn test
```

Test a specific file
```sh
yarn test --match-path test/MyTest.t.sol
```

Test a specific test
```sh
yarn test --match-path test/MyTest.t.sol --match-test testFoobar
```

## Deploy & Verify
This will run each deploy the script `MyScript.s.sol` inside `script/` folder.
```sh
yarn deploy --network <network-name> --script <my-script-name>
```

## Dependencies
use `package.json` `libs` field to specify the git dependency lib with the commit hash.
run `yarn` again to update them.

## Updating Foundry
This will update to the latest Foundry release
```
foundryup
```

## Playground
Playground is a place to make quick tests. Everything that could be inside a normal test can be used there.
Use case can be to test out some gas optimisation, decoding some data, play around with solidity, etc.
```
yarn playground
```

## Verify contract example

### Using Barebone Forge
Use deployments/MyContract.json to get the information needed for the verification

```
forge verify-contract --chain-id 1 --num-of-optimizations 200 --watch --constructor-args $(cast abi-encode "constructor(address,address[])" "<address>" "[<address>,address]") --compiler-version v0.8.16+commit.07a7930e <contract-address> src/MyContract.sol:MyContract -e <etherscan-api-key>
```

### Using Deployment File
```
yarn task verify --deployment Avalanche_ElevatedMinterBurner_Mock  --network avalanche  --artifact src/periphery/ElevatedMinterBurner.sol:ElevatedMinterBurner
```

Where `Avalanche_ElevatedMinterBurner_Mock` is the deployment json file inside `deployments/` and `src/periphery/ElevatedMinterBurner.sol:ElevatedMinterBurner` the `<contract-path>:<contract-name>` artifact.

### Examples
#### Deploy a script on all chains
```
yarn task forge-deploy-multichain --script Create3Factory --broadcast --verify all
```

#### Deploy a script on some chains, without confirmations
```
yarn task forge-deploy-multichain --script Create3Factory --broadcast --no-confirm --verify mainnet polygon avalanche
```

### Deploy Create3Factory
- Use create3Factories task to deploy a new version on all chain.
- If you want to add an existing one to another chain:
    - need to be deployed from the same msg.sender
    - copy hexdata from the create3factory of the one you want to deploy at the same address to another chain
    - send hexdata to 0x4e59b44847b379578588920cA78FbF26c0B4956C (create2 factory) using metamask hexdata field, for example.
    - copy paste existing deployment from deployments/. Like Arbitrum_Create3Factory.json to the new chain deployment
    - change the deployment file name + txHash at the bottom of the file
    - verify the contract, for example:
        `yarn task verify --network base --deployment Base_Create3Factory --artifact src/mixins/Create3Factory.sol:Create3Factory`

## Example on how to deploy manually
This isn't the preferred way to deploy and should be the last resort when the RPC can't work properly with `forge script`.

```
forge create --rpc-url <rpc> \
    --constructor-args 0x591199E16E006Dec3eDcf79AE0fCea1Dd0F5b69D "magicCurveLP MIM-USDT" "mCurveLP-MIM-USDT"  \
    --private-key $PRIVATE_KEY \
    --verify --verifier blockscout --verifier-url https://kavascan.com/api? \
    --legacy \
    src/tokens/MagicCurveLp.sol:MagicCurveLp
```

Then create a deployement file with at least the contract address in it.

And to interact:

```
cast send --rpc-url <rpc> \
    --private-key $PRIVATE_KEY \
    --legacy \
    0x729D8855a1D21aB5F84dB80e00759E7149936e30 \
    "setStaking(address)" \
    0xdC398735150d538B2F18Ccd13A55F6a54488a677
```

## Deploy & Verify manually on Kava
```
forge create --rpc-url <rpc> \
--constructor-args <arg1> <arg2> <arg3> \
    --private-key $PRIVATE_KEY \
    --verify --verifier blockscout --verifier-url https://kavascan.com/api? \
    --legacy \
    src/strategies/StargateLPStrategy.sol:StargateLPStrategy
```

```
forge verify-contract --chain-id 2222 --num-of-optimizations 800 --watch --constructor-args $(cast abi-encode "constructor(address,address[])" "<address>" "[<address>,address]") --compiler-version v0.8.20+commit.a1b79de6 <address> src/strategies/StargateLPStrategy.sol:StargateLPStrategy --verifier blockscout --verifier-url https://kavascan.com/api?
```