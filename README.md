# Abracadabra Money Contracts

## Prerequisites
- Foundry
- Make

## Getting Started

Initialize
```sh
make init
```

Make a copy of `.env.example` to `.env` and set the desired parameters. This file is git ignored.

Build and Test.

```sh
make build
make test
```

## Deploy & Verify
This will run each deploy script inside `script/` folder.
```sh
make mainnet-deploy
```

This will deploy and verify the contracts. If this fails at the verification process, `resume` can be used.
```sh
make mainnet-deploy-resume
```

## Run a single script
By default the Makefile task is going to loop through all the scripts inside `scripts/` and run each one of them in filename-order.
To run only a specific script use the `SCRIPT` environment variable.

```sh
SCRIPT=CauldronV4WithRewarder make arbitrum-deploy
```

## Installing Libs
```sh
forge install <git repo name><@optionnal_tag_or_commit_hash>
make remappings
```
Update `.vscode/settings.json` to add the lib to `git.ignoredRepositories` list

### Update a lib
```
foundry update lib/<package>
```
> Note: If pushing from vscode git, the updated libs might need to be removed from the `git.ignoredRepositories` list to be able to stage.

## Updating Foundry
This will update to the latest Foundry release
```
foundryup
```

## Playground
Playground is a place to make quick tests. Everything that could be inside a normal test can be used there.
Use case can be to test out some gas optimisation, decoding some data, play around with solidiy, etc.
```
make playground
```

Avoid committing playground changes. This will ignore any modifications made to files inside `playground/`.
```
git update-index --assume-unchanged playground/*
```

## Verify contract example
Use deployments/MyContract.json to get the information needed for the verification

```
forge verify-contract --chain-id 1 --num-of-optimizations 200 --watch --constructor-args $(cast abi-encode "constructor(address,address[])" "<address>" "[<address>,address]") --compiler-version v0.8.16+commit.07a7930e <contract-address> src/MyContract.sol:MyContract <etherscan-api-key>
```