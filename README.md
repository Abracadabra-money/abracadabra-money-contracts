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
This will run each deploy the script `MyScript.s.sol` inside `script/` folder.
```sh
SCRIPT=MyScript make mainnet-deploy
```

`<chain>-deploy-resume` can be used if some contracts failed at the verification process, 
```sh
SCRIPT=MyScript make mainnet-deploy-resume
```

## Installing Libs
```sh
forge install <git repo name><@optionnal_tag_or_commit_hash>
make remappings
```
Update `.vscode/settings.json` to add the lib to `git.ignoredRepositories` list

### Update a lib
```
forge update lib/<package>
```
> Note: If pushing from vscode git, the updated libs might need to be removed from the `git.ignoredRepositories` list to be able to stage.

## Updating Foundry
This will update to the latest Foundry release
```
foundryup
```

## Playground
Playground is a place to make quick tests. Everything that could be inside a normal test can be used there.
Use case can be to test out some gas optimisation, decoding some data, play around with solidity, etc.
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
