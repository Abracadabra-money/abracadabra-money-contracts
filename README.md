# Contracts

## Prerequisites
### Rust
https://www.rust-lang.org/learn/get-started

### Foundry
https://book.getfoundry.sh/getting-started/installation

### Make
Should be installed by default on Unix-like OS.
On windows, it can be installed easily using `Chocolatey` package manager
```
choco install make
```

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
> Warning: Etherscan verification on Windows seems broken. MacOS or Linux should be used for production deployment.

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
