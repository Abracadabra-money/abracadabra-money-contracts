// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {BlastOnboarding} from "/blast/BlastOnboarding.sol";
import {BlastOnboardingData} from "/blast/BlastOnboarding.sol";
import {Router} from "/mimswap/periphery/Router.sol";
import {IFeeRateModel} from "/mimswap/interfaces/IFeeRateModel.sol";
import {IFactory} from "/mimswap/interfaces/IFactory.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {DecimalMath} from "/mimswap/libraries/DecimalMath.sol";
import {LockingMultiRewards} from "staking/LockingMultiRewards.sol";

address constant USDB = 0x4300000000000000000000000000000000000003;
address constant MIM = 0x76DA31D7C9CbEAE102aff34D3398bC450c8374c1;
uint256 constant FEE_RATE = 0.0005 ether; // 0.05%
uint256 constant K = 0.00025 ether; // 0.00025, 1.25% price fluctuation, similar to A2000 in curve
uint256 constant I = 0.998 ether; // 1 MIM = 0.998 USDB
uint256 constant USDB_TO_MIN = 1.002 ether; // 1 USDB = 1.002 MIM
uint256 constant MIM_TO_MIN = I;

// Add a new data contract each bootstrap upgrade that involves
// adding new storage variables.
contract BlastOnboardingBootDataV1 is BlastOnboardingData {
    address public pool;
    Router public router;
    IFactory public factory;
    uint256 public totalPoolShares;
    bool public ready;
    LockingMultiRewards public staking;
    mapping(address user => bool claimed) public claimed;
}

/// @dev Functions are postfixed with the version number to avoid collisions
contract BlastOnboardingBoot is BlastOnboardingBootDataV1 {
    using SafeTransferLib for address;

    event LogReadyChanged(bool ready);
    event LogClaimed(address indexed user, uint256 shares, bool lock);
    event LogInitialized(Router indexed router);
    event LogLiquidityBootstrapped(address indexed pool, address indexed staking, uint256 amountOut);
    event LogStakingChanged(address indexed staking);

    error ErrInsufficientAmountOut();
    error ErrNotReady();
    error ErrAlreadyClaimed();
    error ErrWrongFeeRateModel();
    error ErrAlreadyBootstrapped();
    error ErrNothingToClaim();
    error ErrCannotChangeOnceReady();

    //////////////////////////////////////////////////////////////////////////////////////
    /// PUBLIC
    //////////////////////////////////////////////////////////////////////////////////////

    function claim(bool lock) external returns (uint256 shares) {
        if (!ready) {
            revert ErrNotReady();
        }
        if (claimed[msg.sender]) {
            revert ErrAlreadyClaimed();
        }

        shares = _claimable(msg.sender);
        if (shares == 0) {
            revert ErrNothingToClaim();
        }

        claimed[msg.sender] = true;
        staking.stakeFor(msg.sender, shares, lock);

        emit LogClaimed(msg.sender, shares, lock);
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// VIEWS
    //////////////////////////////////////////////////////////////////////////////////////

    function claimable(address user) external view returns (uint256 shares) {
        if (!ready || claimed[user]) {
            return 0;
        }

        return _claimable(user);
    }

    function previewTotalPoolShares() external view returns (uint256 baseAdjustedInAmount, uint256 quoteAdjustedInAmount, uint256 shares) {
        uint256 baseAmount = totals[MIM].locked;
        uint256 quoteAmount = totals[USDB].locked;
        return router.previewCreatePool(I, baseAmount, quoteAmount);
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// ADMIN
    //////////////////////////////////////////////////////////////////////////////////////

    function bootstrap(uint256 minAmountOut) external onlyOwner onlyState(State.Closed) returns (address, address, uint256) {
        if (pool != address(0)) {
            revert ErrAlreadyBootstrapped();
        }

        uint256 baseAmount = totals[MIM].locked;
        uint256 quoteAmount = totals[USDB].locked;
        MIM.safeApprove(address(router), type(uint256).max);
        USDB.safeApprove(address(router), type(uint256).max);

        (pool, totalPoolShares) = router.createPool(MIM, USDB, FEE_RATE, I, K, address(this), baseAmount, quoteAmount);

        if (totalPoolShares < minAmountOut) {
            revert ErrInsufficientAmountOut();
        }

        // Create staking contract
        // 3x boosting for locker, 7 days reward duration, 13 weeks lp locking
        // make this contract temporary the owner the set it as an operator
        // for permissionned `stakeFor` during the claiming process and then
        // transfer the ownership to the onboarding owner.
        staking = new LockingMultiRewards(pool, 30_000, 7 days, 13 weeks, address(this));
        staking.setOperator(address(this), true);
        staking.transferOwnership(owner);

        // Approve staking contract
        pool.safeApprove(address(staking), totalPoolShares);

        emit LogLiquidityBootstrapped(pool, address(staking), totalPoolShares);

        return (pool, address(staking), totalPoolShares);
    }

    function initialize(Router _router) external onlyOwner {
        router = Router(payable(_router));
        factory = IFactory(router.factory());
        emit LogInitialized(_router);
    }

    // Just in case we need to change the staking contract after
    // the automatic bootstrapping process
    function setStaking(LockingMultiRewards _staking) external onlyOwner {
        if (ready) {
            revert ErrCannotChangeOnceReady();
        }

        staking = _staking;
        emit LogStakingChanged(address(_staking));
    }

    function setReady(bool _ready) external onlyOwner onlyState(State.Closed) {
        ready = _ready;
        emit LogReadyChanged(ready);
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// INTERNALS
    //////////////////////////////////////////////////////////////////////////////////////

    function _claimable(address user) internal view returns (uint256 shares) {
        uint256 totalLocked = totals[MIM].locked + totals[USDB].locked;

        if (totalLocked == 0) {
            return 0;
        }

        uint256 userLocked = balances[user][MIM].locked + balances[user][USDB].locked;
        return (userLocked * totalPoolShares) / totalLocked;
    }
}
