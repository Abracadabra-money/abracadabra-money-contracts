# Abracadabra Money Contracts

## Prerequisites
- Foundry
- Make

## Getting Started

Initialize
```sh
make init
```

Build and Test
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

## Installing Libs
```sh
forge install <git repo name><@optionnal_tag_or_commit_hash>
make remappings
```
Update `.vscode/settings.json` to add the lib to `git.ignoredRepositories` list

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
