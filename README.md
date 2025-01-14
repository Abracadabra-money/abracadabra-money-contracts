# Abracadabra Money Contracts

## Prerequisites
- Foundry
- Bun
- [Halmos](https://github.com/a16z/halmos) (optional)
- Linux / MacOS / WSL 2

## Foundry Version
```
foundryup -v nightly-70cd140131cd49875c6f31626bdfae08eba35386
```

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
bun install
```

Make a copy of `.env.defaults` to `.env` and set the desired parameters. This file is git ignored.

Build and Test.

```sh
bun run build
bun run test
```

Test a specific file
```sh
bun run test --match-path test/MyTest.t.sol
```

Test a specific test
```sh
bun run test --match-path test/MyTest.t.sol --match-test testFoobar
```

## Symbolic Execution Test
To run the symbolic execution tests, you need to have Halmos installed.

Run all symbolic tests.
```sh
bun run symtest
```

Run symbolic test for a specific contract.
```sh
bun run symtest --contract FooBarSymTestContract
```

Run specific symbolic.
```sh
bun run symtest --function proveFooBar
```

## Create deployer wallet (keystore)
When using `WALLET_TYPE=keystore`, you need to create a keystore file for the deployer.
```sh
cast wallet import deployer -i
```
> More info [https://book.getfoundry.sh/reference/cast/cast-wallet-import](https://book.getfoundry.sh/reference/cast/cast-wallet-import)

## Deploy & Verify
This will run each deploy the script `MyScript.s.sol` inside `script/` folder.
```sh
bun run deploy --network <network-name> --script <my-script-name>
```

For chains that don't support verify on deploy, you can use the `verify` task after the deploy.
```sh
bun run deploy:no-verify --network <network-name> --script <my-script-name>
bun run task verify --network <network-name> --deployment <deployment-name>
```

## Dependencies
use `libs.json` to specify the git dependency lib with the commit hash.
run `bun install` again to update them.

## Updating Foundry
This will update to the latest Foundry release
```
foundryup
```

## Playground
Playground is a place to make quick tests. Everything that could be inside a normal test can be used there.
Use case can be to test out some gas optimisation, decoding some data, play around with solidity, etc.

```
bun run playground
```

## Verify contract example

### Using Deployment File
```
bun run task verify --deployment Avalanche_ElevatedMinterBurner_Mock  --network avalanche
```

### Using Barebone Forge
Use deployments/MyContract.json to get the information needed for the verification

```
forge verify-contract --chain-id 1 --num-of-optimizations 200 --watch --constructor-args $(cast abi-encode "constructor(address,address[])" "<address>" "[<address>,address]") --compiler-version v0.8.16+commit.07a7930e <contract-address> src/MyContract.sol:MyContract -e <etherscan-api-key>
```


Where `Avalanche_ElevatedMinterBurner_Mock` is the deployment json file inside `deployments/` and `src/periphery/ElevatedMinterBurner.sol:ElevatedMinterBurner` the `<contract-path>:<contract-name>` artifact.

### Examples
#### Deploy a script on all chains
```
bun run task forge-deploy-multichain --script Create3Factory --broadcast --verify all
```

#### Deploy a script on some chains, without confirmations
```
bun run task forge-deploy-multichain --script Create3Factory --broadcast --no-confirm --verify mainnet polygon avalanche
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
        `bun run task verify --network base --deployment Base_Create3Factory --artifact src/mixins/Create3Factory.sol:Create3Factory`

## Example on how to deploy manually
This isn't the preferred way to deploy and should be the last resort when the RPC can't work properly with `forge script`.

```
forge create --rpc-url <rpc> \
    --constructor-args 0x591199E16E006Dec3eDcf79AE0fCea1Dd0F5b69D "magicCurveLP MIM-USDT" "mCurveLP-MIM-USDT"  \
    --account deployer \
    --verify --verifier blockscout --verifier-url https://kavascan.com/api? \
    --legacy \
    src/tokens/MagicCurveLp.sol:MagicCurveLp
```

Then create a deployment file with at least the contract address in it.

And to interact:

```
cast send --rpc-url <rpc> \
    --account deployer \
    --legacy \
    0x729D8855a1D21aB5F84dB80e00759E7149936e30 \
    "setStaking(address)" \
    0xdC398735150d538B2F18Ccd13A55F6a54488a677
```

## Deploy & Verify manually on Kava
```
forge create --rpc-url <rpc> \
--constructor-args <arg1> <arg2> <arg3> \
    --account deployer \
    --verify --verifier blockscout --verifier-url https://kavascan.com/api? \
    --legacy \
    src/strategies/StargateLPStrategy.sol:StargateLPStrategy
```

```
forge verify-contract --chain-id 2222 --num-of-optimizations 800 --watch --constructor-args $(cast abi-encode "constructor(address,address[])" "<address>" "[<address>,address]") --compiler-version v0.8.20+commit.a1b79de6 <address> src/strategies/StargateLPStrategy.sol:StargateLPStrategy --verifier blockscout --verifier-url https://kavascan.com/api?
```

## Run Echidna Fuzzing

Installation:
```
pip3 install slither-analyzer --user
wget https://github.com/crytic/echidna/releases/download/v2.2.3/echidna-2.2.3-x86_64-linux.tar.gz
tar -xzvf echidna-2.2.3-x86_64-linux.tar.gz

```

Running:
```
bun run echidna
```

> Beware, while echidna is running the fuzzing suite is moved over `src/` folder, this way is can remains in `test/` while it's not used.