# BoundSpell Integration Guide & Explanations

## SPELLv2
- New LayerZero OFT EndpointV2 token.
- Supports native bridging from Mainnet (SpellV2 Adapter) SPELL to altchains.

### Currently Supported Chains:
- **Mainnet**: Old SPELL token - Native
- **Arbitrum**: SPELLv2 - New Bridged ERC20
- **Other chains**: TBD

---

## BoundSPELL
- BoundSPELL is a locked version of SPELLv2 on Arbitrum.
- It's also a LayerZero OFT EndpointV2 token.
- BoundSPELL is native on Arbitrum but can be bridged to Mainnet via SPELLv2.

### Currently Supported Chains:
- **Mainnet**: BoundSPELL - Bridged ERC20
- **Arbitrum**: Native
- **Other chains**: TBD

---

## BoundSpellLocker
- BoundSpellLocker is the only way to create new BoundSPELL tokens from SPELLv2.
- Underlying SPELLv2 can always be redeemed back to SPELLv2 but takes 3 months to be available in full.
- Unlocking SPELLv2 is _not_ vested linearly and is redeemed fully after 3 months.

### Instant Redemption:
- SPELLv2 can be redeemed instantly but incurs a significant tax of 50%.
  - 50% can be redeemed instantly at any time.
  - 30% of the underlying SPELL is burned permanently.
  - 20% is distributed to SpellPower stakers as yields.

### Supported Chains:
- **Arbitrum**

---

## SpellPower
Users can opt to stake BoundSPELL on Arbitrum to earn protocol yields.

This new staking mechanism makes the following obsolete:
- **SSPELL** on Mainnet
- **MSPELL** on Mainnet, Fantom, Arbitrum, Avalanche

> Once SpellPower is activated, users using SSPELL and MSPELL will no longer accrue rewards.  
> No other staking contract will generate rewards except SpellPower on Arbitrum.

### Rewards:
- **MIM** from all Abracadabra cauldrons.
- **BoundSPELL** from BoundSpellLocker instant redemptions.

## Lockup Period
Once a user stakes BoundSPELL, they cannot unstake it for 7 days.

### Supported Chains:
- **Arbitrum**

---

## Contracts

### Mainnet:
- **SPELLv2 Adapter**: `0x48c95D958fd0Ef6ecF7fEb8d592c4D5a70f1AfBE`
- **BoundSPELL**: `0x3577D33FE93BEFDfAB0Fce855784549D6b7eAe43`

### Arbitrum:
- **SPELLv2**: `0x34FbFB3e95011956aBAD82796f466bA88895f214`
- **BoundSPELL**: `0x19595E8364644F038bDda1d099820654900c3042`
- **BoundSpellLocker**: `0xD68a4D4811C4F8263289e5D31DA36a6625e14823`
- **SpellPower Staking**: `0x081bEC437cAd6d34656Df5f1b0bd22fCef02Ca69`

---

## Explanations as Questions

### How do I get SPELLv2 on Mainnet?
- You don’t. It’s only meant for altchains. On Mainnet, it’s still the good ol’ SPELL token.

### Then, how do I get SPELLv2 on Arbitrum?
- **From Mainnet**:
  - Bridge SPELL using the SPELLv2 Adapter.
- **From Arbitrum**:
  - Bridge out SPELL using the Arbitrum native bridge.
  - Wait a few days.
  - Get native SPELL on Mainnet.
  - Bridge SPELL to Arbitrum using our official Abracadabra beaming frontend.

### Could it be simpler to get SPELLv2 on Arbitrum from Arbitrum SPELLv1?
- Yes, we could decide to offer a 1:1 swap on Arbitrum using already bridged SPELLv2 tokens.

### Ok, I got SPELLv2 on Arbitrum. What do I do with it?
- Hold it like SPELLv1, or trade it using new pairs people might launch.
- Mint BoundSPELL by locking it using BoundSpellLocker.
- Use BoundSPELL to stake it in SpellPower staking and earn protocol rewards.
- Bridge it to Mainnet or other chains for use in other protocols.
- Trade BoundSPELL on Arbitrum MIMSwap SPELLv2/BoundSPELL.

---

## MIMSwap SPELLv2/BoundSPELL

### Why?
- BoundSPELL introduces a 3-month lock to redeem SPELLv2.
- Redeeming instantly incurs a 50% tax.
- This opens the door to create a SPELLv2/BoundSPELL MIMSwap pair.

### Benefits:
- All trading fees (100%) on this pair will go to liquidity providers (LPers).
- It gives BoundSPELL a price and better utility as a reward.

---

## Migration Scenarios

### Migration Scenario 1 - User has SPELLv1 on Mainnet and wants to MINT BoundSPELL on Arbitrum:
1. Hold SPELL in your wallet.
2. **TX 1**: Approve SPELL to the SPELLv2 Adapter.
3. **TX 2**: Beam SPELL to Arbitrum using the SPELLv2 Adapter.
4. Wait for LayerZero bridging.
5. Switch network to Arbitrum.
6. Hold SPELLv2 in your Arbitrum wallet.
7. **TX 3**: Approve SPELLv2 on the BoundSpellLocker.
8. **TX 4**: Lock/Mint BoundSPELL on the BoundSpellLocker.

---

### Migration Scenario 2 - User has SPELLv1 on Mainnet and wants to STAKE BoundSPELL on Arbitrum:
1. Follow all steps from Migration Scenario 1.
2. **TX 5**: Approve BoundSPELL on SpellPower.
3. **TX 6**: Stake BoundSPELL.

---

### Migration Scenario 3 - User has SSPELL/MSPELL on Mainnet and wants to mint/stake BoundSPELL:
1. Unstake SPELL/MSPELL.
2. Follow all steps from Migration Scenarios 1 or 2.

---

## Integration
The frontend should handle the different scenarios seamlessly with a multi-step wizard guiding users through the necessary transactions, including the LayerZero bridging process. Key features:
- Checkboxes to let users select what they want to migrate (e.g., SSPELL, MSPELL, wallet SPELL).
- Clear information about deprecated contracts and the benefits of migrating.

---

# API Overview
Here are the main functions to implement for bridging and staking. Additional functions not listed here are available on the contracts.

## OFT EndpointV2 Bridging (SPELLv2, BoundSPELL)
- **Estimate gas for bridging**: `quoteSend(SendParam calldata _sendParam, bool _payInLzToken) external view virtual returns (MessagingFee memory msgFee)`
- **Underlying token**: `token() external view returns (address)`
- **Sending**: `send(SendParam calldata _sendParam, MessagingFee calldata _fee, address _refundAddress) external payable virtual returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt)`

## BoundSpellLocker
- **Mint**: `mint(uint256 _amount, address _to) external`  
  - Returned mint amount is the same as the amount sent. 1:1.
- **Instant Redemption**: `instantRedeem(uint256 _amount, address _to) external returns (uint256)`
- **Redeem (3 months)**: `redeem(uint256 _amount, address _to, uint256 _lockingDeadline) external returns (uint256)`  
  - `_to` specifies where the unlocked SPELLv2 will be sent once `claim()` is called.
- **Claim Ready SPELLv2**: `claim() external returns (uint256)`
- **Claimable**: `claimable(address _user) external view returns (uint256)`  
  - Returns the amount of SPELLv2 that can be claimed by the user using `claim()`.
- **Balances**: `balances(address _user) external view returns (uint256 locked, uint256 unlocked)`  
  - Returns the amount of SPELLv2 that is locked and unlocked.
- **User Locks**: `userLocks(address _user) external view returns (LockedBalance[] memory)`  
  - Returns the user's locked and unlocked SPELLv2 balances.

## SpellPower
- All functions are the same as the already familiar `MultiRewards` contract, except for the lockup period.
- **Lockup Period**: `lockupPeriod() external view returns (uint256)`  
  - Returns the lockup period in seconds. Currently set to 7 days.
