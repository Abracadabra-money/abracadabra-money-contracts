# Oracles & Aggregators Guideline
We making a distinction about aggregators and oracles. It's important to take this guideline in consideration as
it can quickly become complicated and hard to follow at time and oracle are a vital part of the ecosystem health.

As a rule of thumb, evern if we unit test the oracle results, we should deploy them first and wait before using it,
validate the price result onchain and monitor.

# Aggregators
- Follows the chainlink standard interface.
- These aggregators should always returns the same decimals as the tokens it's pricing.
- The price should never be altered and give the price when `latestAnswer / 10**decimals` is used.
- They can use other aggregators as well.

# Oracle
- Uses 1..* aggregators. Ideally not using other IOracle implementations but only aggregators.
- Oracle should always be inverted so that it gives how many 1 unit of token they are worth.
- The unit is usually USD but is dictacted by the underlying aggregator used. For example an aggregator
    returning the pricing in ETH, once inverted in the oracle will mean how many tokens 1ETH is worth.
- Decimals should be the same as the token it's pricing.
