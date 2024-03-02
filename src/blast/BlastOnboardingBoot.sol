// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {BlastOnboarding} from "/blast/BlastOnboarding.sol";
import {BlastOnboardingData} from "/blast/BlastOnboarding.sol";
import {Router} from "/mimswap/periphery/Router.sol";
import {IFeeRateModel} from "/mimswap/interfaces/IFeeRateModel.sol";
import {IFactory} from "/mimswap/interfaces/IFactory.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

import "forge-std/console2.sol";

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
    bool public ready;
    mapping(address user => bool claimed) public claimed;
}

/// @dev Functions are postfixed with the version number to avoid collisions
contract BlastOnboardingBoot is BlastOnboardingBootDataV1 {
    using SafeTransferLib for address;

    event LogReadyChanged(bool ready);
    event LogClaimed(address indexed user);
    event LogRouterChanged(Router indexed router);

    error ErrInsufficientAmountOut();
    error ErrNotReady();
    error ErrAlreadyClaimed();
    error ErrWrongFeeRateModel();
    error ErrAlreadyBootstrapped();
    error ErrExcessivePoolBalance();

    //////////////////////////////////////////////////////////////////////////////////////
    /// PUBLIC
    //////////////////////////////////////////////////////////////////////////////////////

    function claim(address user) external {
        if (!ready) {
            revert ErrNotReady();
        }
        if (claimed[user]) {
            revert ErrAlreadyClaimed();
        }

        claimed[user] = true;

        emit LogClaimed(user);
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// ADMIN
    //////////////////////////////////////////////////////////////////////////////////////

    function bootstrap(uint256 minAmountOut) external onlyOwner onlyState(State.Closed) ensureNoMaintainerFee returns (uint256 amountOut) {
        if (pool != address(0)) {
            revert ErrAlreadyBootstrapped();
        }

        // Create the empty pool
        pool = IFactory(factory).create(MIM, USDB, FEE_RATE, I, K);

        uint256 baseAmount = totals[MIM].locked;
        uint256 quoteAmount = totals[USDB].locked;
        MIM.safeApprove(address(router), type(uint256).max);
        USDB.safeApprove(address(router), type(uint256).max);

        (uint256 baseAdjustedInAmount, uint256 quoteAdjustedInAmount, ) = router.previewAddLiquidity(pool, baseAmount, quoteAmount);
        (pool, amountOut) = router.createPool(MIM, USDB, FEE_RATE, I, K, address(this), baseAdjustedInAmount, quoteAdjustedInAmount);

        baseAmount -= baseAdjustedInAmount;
        quoteAmount -= quoteAdjustedInAmount;

        address[] memory path = new address[](1);
        path[0] = pool;

        // Swap remaining
        // minimumOut of 0 are intended as the whole amount is safeguard globally by minAmountOut
        for (uint256 i = 0; i < 10; i++) {
            // remaining 0.1 ether is considered dust
            if (baseAmount <= 0.1 ether && quoteAmount <= 0.1 ether) {
                break;
            }

            // 50% MIM -> USDB
            if (baseAmount > quoteAmount) {
                console2.log("swap MIM -> USDB");
                console2.log("baseAmount", baseAmount);
                console2.log("quoteAmount", quoteAmount);
                baseAmount -= baseAmount / 2;
                quoteAmount = router.swapTokensForTokens(address(this), baseAmount, path, 0x0, 0, type(uint256).max) + quoteAmount;
                console2.log("--->");
                console2.log("baseAmount", baseAmount);
                console2.log("quoteAmount", quoteAmount);
                console2.log(MIM.balanceOf(address(this)));
                console2.log(USDB.balanceOf(address(this)));
            }
            // 50% USDB -> MIM
            else {
                console2.log("swap USDB -> MIM");
                console2.log("baseAmount", baseAmount);
                console2.log("quoteAmount", quoteAmount);
                quoteAmount -= quoteAmount / 2;
                baseAmount = router.swapTokensForTokens(address(this), quoteAmount, path, 0x1, 0, type(uint256).max) + baseAmount;
                console2.log("--->");
                console2.log("baseAmount", baseAmount);
                console2.log("quoteAmount", quoteAmount);
            }

            (baseAdjustedInAmount, quoteAdjustedInAmount, ) = router.previewAddLiquidity(pool, baseAmount, quoteAmount);
            uint256 newAmountOut = router.addLiquidityUnsafe(pool, address(this), baseAmount, quoteAmount, 0, type(uint256).max);

            amountOut += newAmountOut;

            console2.log("baseAmount", baseAmount);
            console2.log("quoteAmount", quoteAmount);
            console2.log("baseAdjustedInAmount", baseAdjustedInAmount);
            console2.log("quoteAdjustedInAmount", quoteAdjustedInAmount);

            baseAmount -= baseAdjustedInAmount;
            quoteAmount -= quoteAdjustedInAmount;
        }

        // should be safeguarded by the approve amounts, but just in case.
        // balance inside the pool should never exceed locked amounts
        if (MIM.balanceOf(pool) > totals[MIM].locked || USDB.balanceOf(pool) > totals[USDB].locked) {
            revert ErrExcessivePoolBalance();
        }

        if (amountOut < minAmountOut) {
            revert ErrInsufficientAmountOut();
        }
    }

    function setRouter(Router _router) external onlyOwner {
        router = Router(payable(_router));
        factory = IFactory(router.factory());
        emit LogRouterChanged(_router);
    }

    function setReady(bool _ready) external onlyOwner onlyState(State.Closed) {
        ready = _ready;
        emit LogReadyChanged(ready);
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// MODIFIERS
    //////////////////////////////////////////////////////////////////////////////////////

    /// @dev Ensure to not take maintainer fee on liquidity bootstrapping
    modifier ensureNoMaintainerFee() {
        IFeeRateModel feeRateMode = IFeeRateModel(factory.maintainerFeeRateModel());
        (uint256 adjustedLpFeeRate, uint256 mtFeeRate) = feeRateMode.getFeeRate(address(this), FEE_RATE);

        if (adjustedLpFeeRate != FEE_RATE || mtFeeRate != 0) {
            revert ErrWrongFeeRateModel();
        }
        _;
    }
}
