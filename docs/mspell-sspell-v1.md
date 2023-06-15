# mSpell and sSpell V1 Infra Notes

## Components
The following components are part of the mSpell and sSpell V1 infrastructure:

- `MSpellSender`: Located on Mainnet, responsible for sending spells.
- `MSpellReport`: Found on every chain except Mainnet, used for reporting staked MIM amounts.
- `CauldronFeeWithdrawer`: Present on every chain, including Fantom which still uses `MultichainWithdrawer`. It auto-bridges to Mainnet, while `CauldronFeeWithdrawer` requires explicit calls to `bridgeAll`.
- `AnySwap Bridge`: Used on every chain except Mainnet to send MIM tokens to Mainnet's `CauldronFeeWithdrawer`.
- `LayerZero`: Utilized for transaction processing and confirmation.
- `MSpellStaking`: Contracts where MIM tokens are staked for each chain.
- `InchSpellSwapper`: Contract used for transferring MIM to sSpell rewards.

## Withdrawal Process
Gelato initiates the `withdraw()` function on every chain's `CauldronFeeWithdrawer`. However, Fantom still utilizes `MultichainWithdrawer` for withdrawal, but the key difference is that it automatically bridges to Mainnet. On the other hand, `CauldronFeeWithdrawer` requires an explicit call to `bridgeAll` to transfer funds to Mainnet.

- On every chain except Mainnet, the `withdraw()` action sends MIM tokens using the `AnySwap Bridge` to Mainnet's `CauldronFeeWithdrawer`.
- On Mainnet, when the `withdraw()` function is called, the MIM tokens remain inside the `CauldronFeeWithdrawer`.

## MIM Distribution to MSpellStaking
To determine the amount of MIM to distribute to each `MSpellStaking` contract, `MSpellReporter` is used on every chain except Mainnet. It reports the amount of MIM staked inside each `MSpellStaking` contract, facilitating fair distribution.

## Bridging MIM with `bridgeMim()`
On Mainnet, when the `bridgeMim()` function is called on `MSpellSender`, it takes the MIM tokens from the `CauldronFeeWithdrawer` and distributes them proportionally to each `MSpellStaking` contract. This distribution ensures fairness based on the amount of MIM staked on each chain compared to the total staked across all chains.

## sSpell Staking and Reward Distribution
A portion of the allocated MIM amount is designated for sSpell reward distribution. These MIM tokens are transferred to the `InchSpellSwapper` contract. To automate the MIM swapping process for sSpell reward distribution, a Gelato task is set up. The task executes the MIM swapping from the `InchSpellSwapper` contract to sSpell tokens, facilitating the distribution of sSpell rewards to eligible participants.

