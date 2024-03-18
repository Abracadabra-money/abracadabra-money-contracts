# Overview

Abracadabra engaged Guardian Audits for an in-depth security review of Mimswap and its blast deployment. This comprehensive evaluation, conducted from February 29th to March 11th, 2024, included the development of a specialized fuzzing suite by [@0xScourgedev](https://twitter.com/0xScourgedev). This suite, an integral part of the audit, was created during the review period and successfully delivered upon the audit's conclusion.

# Contents

This fuzzing suite was created for the scope below, and updated for remediations at commit hash [f727d27d27a726c867be3df1c2a8be1a63b5ec7b](https://github.com/Abracadabra-money/abracadabra-money-contracts/tree/f727d27d27a726c867be3df1c2a8be1a63b5ec7b). The fuzzing suite targets the `Router.sol`, `MagicLP.sol` and `Factory.sol` contracts. `PrivateRouter.sol` and the functionality that is included with it was not fuzzed as part of this engagement as it was added during remediations. Additionally, the blast contracts were not fuzzed due to the timeboxed nature of this engagement.

All properties tested can be found in `Properties.md`.

## Setup

1. Install Echidna, follow the steps here: [Installation Guide](https://github.com/crytic/echidna#installation)

2. Install dependencies with `yarn install`

3. Running Echidna for Fuzzing Invariants

To fuzz all invariants, run the command: 
```
echidna . --contract Fuzz --config echidna-config.yaml --workers <Number of Workers>
```

# Scope

Repo: https://github.com/Abracadabra-money/abracadabra-money-contracts
Branch: `main`
Commit: `ab3ab131c008422768312188d43e95a53191b241`

```
abracadabra-money-contracts/src/blast/BlastWrappers.sol
abracadabra-money-contracts/src/blast/BlastTokenRegistry.sol
abracadabra-money-contracts/src/blast/BlastMagicLP.sol
abracadabra-money-contracts/src/blast/BlastGovernor.sol
abracadabra-money-contracts/src/blast/BlastBox.sol
abracadabra-money-contracts/src/mimswap/MagicLP.sol
abracadabra-money-contracts/src/blast/libraries/BlastYields.sol
abracadabra-money-contracts/src/mimswap/auxiliary/FeeRateModelImpl.sol
abracadabra-money-contracts/src/mimswap/auxiliary/FeeRateModel.sol
abracadabra-money-contracts/src/mimswap/libraries/PMMPricing.sol
abracadabra-money-contracts/src/mimswap/libraries/Math.sol
abracadabra-money-contracts/src/mimswap/libraries/DecimalMath.sol
abracadabra-money-contracts/src/mimswap/periphery/Router.sol
abracadabra-money-contracts/src/mimswap/periphery/Factory.sol
```