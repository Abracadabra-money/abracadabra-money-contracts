# Create a contract from another chain `Contract Creation Code`

## Get the `Contract Creation Code` from source chain
```bash
cast --rpc-url <rpc url> code <address>
```

## Create the contract to destination chain
```bash
 cast send --private-key $PRIVATE_KEY --rpc-url <rpc url> --create <Contract Creation Code>
```