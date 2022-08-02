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
This will run each deploy script inside `script/` folder
```sh
make mainnet-deploy
```

## Updating Mappings
```sh
forge remappings > remappings.txt
```