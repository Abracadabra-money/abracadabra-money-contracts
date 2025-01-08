# BoundSpell Integration Guide & Explanations

## SPELLv2
- New LayerZero OFT EndpointV2 token
- Supports native bridging from Mainnet (SpellV2 Adapter) SPELL to altchains.

Currently Supported Chains:
- Mainnet (Old SPELL token - Native)
- Arbitrum (SPELLv2 - New Bridged ERC20)
- other chains TBD

## BoundSPELL
- BoundSPELL is a locked version of SPELLv2 on Arbitrum.
- It's also a LayerZero OFT EndpointV2 token which.
- BoundSPELL is native on Arbitrum but can be bridged to Mainnet via SPELLv2.

Currently Supported Chains:
- Mainnet (boundSPELL - BridgedERC20)
- Arbitrum (Native)
- other chains TBD

## BoundSpellLocker
- BoundSpellLocker is the only way to create new boundSPELL token from SPELLv2.
- Underlying Spellv2 can always be redeemed back to Spellv2 but takes 3 months to be available in whole.
- Unlocking Spellv2 are _not_ vested linearly and redeemed fully after 3 months.

Instant redemption:
- Spellv2 can be redeemed atomically but induce a significant tax of 50%.
- Only 50% can be redeemed instantly in any time.
- 30% of the underlying SPELL is burned forever
- 20% is distributed to SpellPower stakers as yields.

Supported Chains:
- Arbitrum

## SpellPower
Users can opt to stake boundSPELL on Arbitrum to earn protocol yields.

This new staking mark obsolete the following staking:
- SSPELL on Mainnet
- MSPELL on Mainnet, Fantom, Arbitrum, Avalanche

> Once SpellPower is activated, users using SSPELL and MSPELL will no longer accrue rewards.
> No other staking contract will generate rewards but only SpellPower on Arbitrum.

Rewards:
- MIM from all abracadabra cauldrons.
- BoundSPELL from BoundSpellLocker instant redemptions

Supported Chains:
- Arbitrum

# Contracts
## Mainnet
SPELLv2 Adapter: 0x48c95D958fd0Ef6ecF7fEb8d592c4D5a70f1AfBE
BoundSPELL: 0x3577D33FE93BEFDfAB0Fce855784549D6b7eAe43

## Arbitrum
SPELLv2: 0x34FbFB3e95011956aBAD82796f466bA88895f214
BoundSPELL: 0x19595E8364644F038bDda1d099820654900c3042
BoundSpellLocker: 0xD68a4D4811C4F8263289e5D31DA36a6625e14823
SpellPower staking: 0x081bEC437cAd6d34656Df5f1b0bd22fCef02Ca69

# Explanations as questions

# How do I get SpellV2 on Mainnet?
- You don't, it's only meant for altchains. On Mainnet it's still the good ol' SPELL token

# Then, how do I get SpellV2 on Arbitrum?
- From Mainnet:
- bridge SPELL using Spellv2 Adapter

- From Arbitrum:
- bridge out SPELL using the Arbitrum native bridge
- wait few days
- get native SPELL on mainnet
- bridge SPELL to arbitrum using our official abracadabra beaming frontend.

# Could it be simpler to get SPELLv2 on Arbitrum from Arbitrum SPELLv1?
- Yes we could decide to offer a swap 1:1 on Arbitrum using already bridge SPELLv2 tokens.

# Ok I got SPELLv2 on Arbitrum, what do I do with it?
- Hold it like SPELLv1, Trade it using new pairs people could launch.
- Mint boundSPELL by locking it using BoundSpellLocker
- Use boundSPELL to stake it to SpellPower staking and earn protocol rewards.
- Bridge it to mainnet or other chains to use on other protocols integrating it.
- Trade boundSPELL on Arbitrum MIMSwap SPELLv2/boundSPELL

# MIMSwap SPELLv2/boundSPELL ?!
- Given there's a 3 months lock to get back your SPELLv2 from boundSPELL
- Given there's a 50% tax on getting the SPELLv2 instantly
- It opens a door to create a SPELLv2/boundSPELL MIMSwap pair.
- On that pair, 100% of the trading fees will be directed to the LPers.

# Why?
- We will no longer give SPELL rewards, nor mint new ones (TBB), boundSPELL will be given instead
- By having a pair for it, it gives a price to boundSPELL
- Since you can always give the underlying SPELLv2 from boundSPELL (3 months) there's a confidence in arbing SPELLv2/boundSPELL

# Arbing SPELLv2/boundSPELL?
- _Conceptually_ 1 boundSPELL = 1 SPELL. 1:1
- Let's say someone gets $50,000 worth of boundSPELL rewards.
- He can dump it immediately on SPELLv2/boundSPELL minus the slippage and price impact on the pool
- Now boundSPELL is much lower than SPELLv2
- You have some bot that ape into buying boundSPELL cheaper
- Since it's on Arbitrum, it's cheap to arbitrage
- You get free SPELL by buying boundSPELL once you redeem it.

# Who will create SPELLv2/boundSPELL?
- People interessting in getting trading fees from SPELLv2 <> boundSPELLv2 swaps.

# Is this pair necessary?
- Not at all, it's a derivating product.
- It doesn't protect SPELL price as much as if it wouldn't exist but,
- by including it in our product line upfront, in return, we can put a price on boundSPELL and better use it as reward.
- Offering arbitrage,speculative,strategy over an ecosystem can be fun.

# What else can you do with boundSPELL
- Voting: boundSPELL would be the new governance token
- Snapshot rules would be updated to account for it (in wallet or staked in spellpower)

# Integration
Frontend should make it easy to handle the different scenarios, see the following sections for more details about the migrations scenarios.

# SSPELL and MSPELL deprecation
Frontend should make it clear that we sunsetted those and that the user needs to migrate to SpellPower and optionaly sugggest to provide liquidity the spell/bSpell mimswap pool.

> I'm suggesting a easy to use multi-step wizard on the frontend that will be asking he users different transactions to sign until he is finished.
> The migration wizard could have checkboxes to let the user select what he wants to migrate (sspell, mspell, wallet spell)

Some obvious migration scenarios we can think of:

# Migration Scenarios 1 - User have SPELLv1 on Mainnet and wants to MINT boundSPELL on Arbitrum
- He hold SPELL in his wallet
- TX 1: Approve SPELL to SPELLv2 Adapter.
- TX 2: Beam SPELL to Arbitrum using SPELLv2 Adapter. (optionnaly Airdrop ETH to Arbitrum if possible, if user have no ETH, tbd)
- Wait for LayerZero bridging
- Switch network to arbitrum
- User hold SPELLv2 on its Arbitrum Wallet.
- TX 3: Approve SPELLv2 on BoundSpellLocker
- TX 4: Lock / Mint boundSPELL on BoundSpellLocker

# Migration Scenerio 2 - User have SPELLv1 on Mainnet and wants to STAKE boundSPELL on Arbitrum
- Same as Migration Scenarios 1
- TX 5: Approve boundSPELL on SpellPower
- TX 6: Stake

# Migration Scenario 3 - User have SSPELL/MSPELL on Mainnet and wants to mint/stake/lp boundspell
- Unstake SPELL/MSPELL
- Same as Migration Scenarios 1 or 2

etc...

# API
