# MIM Saving Rate Integration Guide

The MSR consist of the `LockingMultiRewards` contract. It is similar to the existing `MultiRewards` except that a user can lock their deposit for boosted rewards.

> Users can have up to `maxLocks` and they are aligned per `rewardsDuration` (week).
If a user stake-lock during the same week, it gets added-up. But the minimal amount
to create a new lock is `minLockAmount`.

> Locks are release offchain with a gelato task.

# Views
`lockDuration() returns uint`
- Duration in seconds when a user decide to lock their amount. (should be 13 weeks in prod)

`lockingBoostMultiplerInBips() returns (uint)`
- 30_000 = 300% boost when locking

`rewardsDuration`
- Same as `MultiRewards` but fixed for all tokens, (should be 1 week in prod)

`unlocked(user)`
- Unlocked amount for a user, when a user stake without locking, it's added up to it.
- Once a lock is released, it gets added to unlocked.

`balanceOf(user)`
- Virtual amount of the use taking in account the current user's boosting.
- **Doesn't** mean the user has `balanceOf` token in the contract.
  
`earned(user, toke)`
- Same as `MuliRewards` contract.

`minLockAmount`
- Cannot lock less than this amount **PER LOCK**

`nextUnlockTime`
- If a user lock at this moment, when the lock is going to be released.

`lastLockIndex`
- The `userLocks` index when the most recent lock is.
  
`userLocks`
- Current amount of lock returned with `userLocksLength`
- Up to `maxLocks`
- Each lock has `amount` and `unlockTime`.
- when `unlockTime` of `lastLockIndex` most recent lock is the same as `nextUnlockTime`
  - locking an amount is going to added to the existing lock
  - there's no `minLockAmount` check.

# Deposit
`stake(uint amount, bool lock)`
- Requires approval
- Transfer tokens from the user
- Lock for `lockDuration()` 
- When locking, need

# Lock
`lock(uint amount)`
- Lock up to `unlocked(user)` amount.
- Use existing tokens in the contract, doesn't transfer new.


# Withdraw
`withdraw(amount)`
- Can only withdraw amount specifiy in `unlocked()`

`getRewards`
- Same as `MultiRewards`

`withdrawWithRewards`
- User to be `exit` in `MultiRewards` but is used to withdraw an unlocked amount and also the rewards.
