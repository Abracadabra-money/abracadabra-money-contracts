# Introduction

This report has been prepared by a highly renowned security researcher whose identity is known to the Abracadabra Team but who would prefer to stay anonymous.

# Summary

MagicGLP allows users to supply GMX LP positions (GLP) as collateral and borrow a stablecoin, Magic Internet Money (MIM).

## Contracts

| Name                   | Address (Arbitrum)                           |
|------------------------|----------------------------------------------|
| MagicGlp (mGLP)        | `0x85667409a723684fe1e57dd1abde8d88c2f54214` |
| MagicGlpRewardHandler  | `0x41b8dbde2d4127111fbedf31783781ae69300026` |
| CauldronV4             | `0x726413d7402ff180609d0ebc79506df8633701b1` |
| ProxyOracle            | `0x4ed0935ecc03d7fcefb059e279bcd910a02f284c` |
| MagicGlpOracle         | `0xa0fc5f7f1a72ae4842b89d5aa42fb8870b599a4b` |
| DegenBoxERC4626Wrapper | `0x565ade5536ab84018e00d6d7f56e7a300717c10b` |
| MagicGlpHarvestor      | `0x588d402c868add9053f8f0098c2dc3443c991d17` |
| MagicGlpSwapper        | `0x2386937474ed353cca2b0531cee31228a7e56a46` |
| MagicGlpLevSwapper     | `0xde36def82f9da4493925407e37e6548d5d9bd7ed` |
| DegenBox               | `0x7c8fef8ea9b1fe46a7689bfb8149341c90431d38` |

### GMX Contracts
| Name                   | Address (Arbitrum)                           |
|------------------------|----------------------------------------------|
| Vault                  | `0x489ee077994b6658eafa855c308275ead8097c4a` |
| GlpManager             | `0x3963ffc9dff443c2a94f21b129d429891e32ec18` |
| RewardRouterV2         | `0xb95db5b167d75e6d04227cfffa61069348d271f5` |
| GLP                    | `0x4277f8f2c384827b5273592ff7cebd9f2c1ac258` |
| RewardTracker (fGLP)   | `0x4e971a87900b931fF39d1Aad67697F49835400b6` |
| RewardTracker (fsGLP)  | `0x1addd80e6039594ee970e5872d247bf0414c8903` |

# System Overview

GLP is a token that represents a liquidity provider position on GMX, a trading and lending protocol.

MagicGLP is a wrapper around GLP that allows holders to earn rewards that accrue to GLP while using their tokens as collateral.

A designated strategy executor periodically calls `run` on `MagicGlpHarvestor` which:
* Claims WETH rewards
* Mints and stakes new `fsGLP` via GMX's `RewardRouterV2`
* Transfers rewards (minus a fee) to MagicGLP
* MagicGLP holders can claim `fsGLP` proportional to their holdings

A `CauldronV4` DegenBox lending market allows MagicGLP holders to use their tokens as collateral and borrow a stablecoin, Magic Internet Money (MIM). The oracle for this market uses GMX's `GLPManager` to value GLP tokens.

Users can perform atomic sequences of actions via `cook` in `CauldronV4` and peripheral contracts `DegenBoxERC4626Wrapper`, `MagicGlpSwapper`, and `MagicGlpLevSwapper`.

# Summary of Findings
| Severity      | Count     |
|---------------|-----------|
| Critical      | 0         |
| High          | 0         |
| Medium        | 2         |
| Low           | 1         |
| Informational | 2         |

# Findings

## M.1 Some users are not withdrawing all of their rewards in the "remove collateral, swap, repay, withdraw" workflow

### Description
In some cases, users are not withdrawing their full `fsGLP` rewards when they redeem MagicGLP after using it as collateral. Some `fsGLP` is being left behind in [DegenBox](https://arbiscan.io/address/0x7C8FeF8eA9b1fE46A7689bfb8149341C90431D38) (notice the balance of `fsGLP` in the contract) that anyone can claim by calling `deposit`.

This is not a smart contract bug, but likely an issue with the frontend or server that interacts with the smart contracts.

### Proof of Concept
https://arbiscan.io/tx/0x0c8e5ef4404bc083c950bd9ce363c17bec9b96cb847edb4dca0910f5f4b2e87f
* This user should have withdrawn 7,841.50 fsGLP but only withdraws 7,793.35, leaving 48.15 fsGLP (~$43) on DegenBox that anyone can claim.
* The `cook` actions in this transaction (and similar transactions with losses) are:
    * Remove collateral
    * Call (swapper)
    * Repay
    * Remove collateral
    * Withdraw (MagicGLP to wrapper)
    * Call (wrapper `redeem`)
    * Withdraw (fsGLP)
* The issue is that the amount passed to the final (fsGLP) withdraw is the same as the amount passed to the penultimate (MagicGLP) withdraw, when it should be higher to account for accrued rewards.

### Mitigation
Pass in the correct final (fsGLP) withdraw amount or use a peripheral contract that withdraws the DegenBox excess balance (`balanceOf` minus `totals`) of fsGLP.

## M.2 Late investors benefit unfairly in a reward cycle

### Description

New MagicGLP is minted based on the simple formula:

$$ MagicGLP\ minted = \frac{fsGLP\ deposited}{fsGLP\ balance} * MagicGLP\ supply $$

However, this means that in the times between when `harvest` is called, investors can mint MagicGLP at the same rate.

This has the effect that an investor who mints MagicGLP late in this cycle will earn some rewards that should have gone to earlier investors.

An advanced attacker could sandwich the `harvest` by making a large deposit directly before and withdrawing directly after.

### Context

**MagicGlp.sol > ERC4626.sol**
```Solidity
function previewDeposit(uint256 assets) public view virtual returns (uint256) {
    return convertToShares(assets);
}

function convertToShares(uint256 assets) public view virtual returns (uint256) {
    uint256 supply = totalSupply;
    return supply == 0 ? assets : assets.mulDivDown(supply, totalAssets());
}

function totalAssets() public view returns (uint256) {
    return _asset.balanceOf(address(this));
}
```

### Proof of Concept
* A new MagicGLP contract is created
* Alice mints 10 million MagicGLP with 10 million fsGLP
* After 1 week, the 10 million GLP accrue 2 WETH in rewards
* Bob mints 10 million MagicGLP with 10 million fsGLP
* In the transaction directly after Bob mints, the strategy executor calls `harvest`
* Alice redeems all her tokens, earning 1 WETH worth of fsGLP rewards
* Bob redeems all his tokens, earning 1 WETH worth of fsGLP rewards
* Without depositing to MagicGLP, Alice would have received 2 WETH in rewards

### Mitigation

A simple mitigation without updating the code is to ensure that rewards are harvested on a regular basis. This makes an attack less profitable and less likely.

In a new system, it could be more fair to mint new MagicGLP based on both the balance of fsGLP in the contract **and** the value of rewards that are earned but not yet harvested. However, this introduces complexity because rewards accrue in WETH.

## L.1 If all of MagicGLP supply is deposited in DegenBox, attacker can steal excess (reward) fsGLP

### Context

**MagicGlp.sol > ERC4626.sol**

```Solidity
function convertToAssets(uint256 shares) public view virtual returns (uint256) {
    uint256 supply = totalSupply;
    return supply == 0 ? shares : shares.mulDivDown(totalAssets(), supply);
}
```

### Proof of Concept
* Suppose MagicGLP total supply 16 million (shares), which can claim 17 million fsGLP (assets)
* Flash loan 16m MagicGLP from DegenBox
* Redeem 16m MagicGLP for 17m fsGLP
* MagicGLP total supply is now zero
* Deposit 16m fsGLP to mint 16m MagicGLP 
* Repay 16m MagicGLP
* Profit 1 million fsGLP

### Mitigation

Although >99% of the MagicGLP supply are in DegenBox, the attack requires 100%. There are currently 56 unique holders of MagicGLP, which makes the attack implausible. Transfer 1 wei of MagicGLP to the burn address `0x0` for additional safety.

## I.1 MagicGlp depends on the security of GLP and by extension, GMX

If a critical bug exists in the GMX protocol or a GMX account with admin privileges is malicious or compromised, funds could be stolen from MagicGlp users as well.

The GMX vault is currently governed by a 24-hour timelock `0xe7e740fa40ca16b15b621b49de8e9f0d69cf4858` with admin account`0x49b373d422bda4c6bfcdd5ec1e48a9a26fda2f8b`.

## I.2 GMX contracts use excessive gas

This could be an issue if block space ever becomes expensive.

To update the oracle via `updateExchangeRate` on `CauldronV4` costs ~750K gas. 