# Contracts

## Prerequisites
- Rust
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
This will run each deploy script inside `script/` folder
```sh
make mainnet-deploy
```

## Updating Mappings
```sh
forge remappings > remappings.txt
```