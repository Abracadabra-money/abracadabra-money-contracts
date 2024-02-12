// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2021 BoringCrypto - All rights reserved
pragma solidity >=0.8.0;

import {DegenBox} from "/DegenBox.sol";
import {BoringERC20} from "BoringSolidity/libraries/BoringERC20.sol";
import {RebaseLibrary, Rebase} from "BoringSolidity/libraries/BoringRebase.sol";
import {BoringMath, BoringMath128} from "BoringSolidity/libraries/BoringMath.sol";
import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {YieldMode, GasMode, IBlast, IERC20Rebasing} from "interfaces/IBlast.sol";
import {OperatableV3} from "mixins/OperatableV3.sol";
import {IWETH} from "interfaces/IWETH.sol";
import {FeeCollectable} from "mixins/FeeCollectable.sol";

interface IDegenBoxBlast {
    function claimETHYields(uint256 amount) external returns (uint256);

    function claimTokenYields(address token, uint256 amount) external returns (uint256);

    function claimGasYields() external returns (uint256);

    function setTokenEnabled(address token, bool enabled, bool supportsNativeYields) external;
}

contract DegenBoxBlast is DegenBox, OperatableV3, FeeCollectable {
    using BoringMath for uint256;
    using BoringMath128 for uint128;
    using RebaseLibrary for Rebase;
    using BoringERC20 for IERC20;

    event LogBlastETHClaimed(uint256 amount);
    event LogBlastGasClaimed(uint256 amount);
    event LogBlastTokenClaimed(address indexed token, uint256 amount);
    event LogBlastYieldAdded(IERC20 indexed token, uint256 userAmount, uint256 feeAmount);
    event LogTokenDepositEnabled(address indexed token, bool previous, bool current, bool yieldEnabled);

    error ErrTokenNotEnabled();

    IBlast constant BLAST_YIELD_PRECOMPILE = IBlast(0x4300000000000000000000000000000000000002);

    mapping(address => bool) public enabledTokens;

    constructor(IERC20 _weth) DegenBox(_weth) {}

    function _onBeforeDeposit(
        IERC20 token,
        address /*from*/,
        address /*to*/,
        uint256 /*amount*/,
        uint256 /*share*/
    ) internal view override {
        if (!enabledTokens[address(token)]) {
            revert ErrTokenNotEnabled();
        }
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// OPERATORS
    //////////////////////////////////////////////////////////////////////////////////////

    function claimETHYields(uint256 amount) external onlyOperators returns (uint256) {
        if (amount == type(uint256).max) {
            amount = BLAST_YIELD_PRECOMPILE.readClaimableYield(address(this));
        }

        emit LogBlastETHClaimed(amount);

        if (feeBips == BIPS) {
            return BLAST_YIELD_PRECOMPILE.claimYield(address(this), feeCollector, amount);
        }

        amount = BLAST_YIELD_PRECOMPILE.claimYield(address(this), address(this), amount);

        IWETH(address(wethToken)).deposit{value: amount}();
        _distributeYields(wethToken, amount);

        return amount;
    }

    function claimTokenYields(IERC20Rebasing token, uint256 amount) external onlyOperators returns (uint256) {
        if (!enabledTokens[address(token)]) {
            revert ErrTokenNotEnabled();
        }

        if (amount == type(uint256).max) {
            amount = token.getClaimableAmount(address(this));
        }

        emit LogBlastTokenClaimed(address(token), amount);

        if (feeBips == BIPS) {
            return token.claim(feeCollector, amount);
        }

        amount = token.claim(address(this), amount);
        _distributeYields(IERC20(address(token)), amount);
        return amount;
    }

    function claimGasYields() external onlyOperators returns (uint256 amount) {
        if (feeBips == BIPS) {
            amount = BLAST_YIELD_PRECOMPILE.claimAllGas(address(this), feeCollector);
            emit LogBlastGasClaimed(amount);
            return amount;
        }

        amount = BLAST_YIELD_PRECOMPILE.claimAllGas(address(this), address(this));

        emit LogBlastGasClaimed(amount);

        IWETH(address(wethToken)).deposit{value: amount}();
        _distributeYields(wethToken, amount);

        return amount;
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// ADMIN
    //////////////////////////////////////////////////////////////////////////////////////

    /// @notice Enable or disable depositing a token
    /// Warning: When disabling a yield token, be sure to claim all the yields first
    function setTokenEnabled(address token, bool enabled, bool supportsNativeYields) external onlyOwner {
        emit LogTokenDepositEnabled(token, enabledTokens[token], enabled, supportsNativeYields);
        enabledTokens[token] = enabled;

        if (supportsNativeYields && enabled) {
            if (enabled) {
                IERC20Rebasing(token).configure(YieldMode.CLAIMABLE);
            } else {
                IERC20Rebasing(token).configure(YieldMode.VOID);
            }
        }
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// INTERNALS
    //////////////////////////////////////////////////////////////////////////////////////

    /// @dev Called on DegenBox's constructor
    function _configure() internal override {
        BLAST_YIELD_PRECOMPILE.configureClaimableYield();
        BLAST_YIELD_PRECOMPILE.configureClaimableGas();
    }

    function _distributeYields(IERC20 token, uint256 amount) internal {
        // Take fees
        (uint userAmount, uint feeAmount) = calculateFees(amount);

        if (feeAmount > 0) {
            token.safeTransfer(feeCollector, feeAmount);
        }

        // Same as a strategy
        if (userAmount > 0) {
            uint256 totalElastic = totals[token].elastic;
            totalElastic = totalElastic.add(userAmount);
            totals[token].elastic = totalElastic.to128();
        }

        emit LogBlastYieldAdded(token, userAmount, feeAmount);
    }

    function isOwner(address _account) internal view override returns (bool) {
        return owner == _account;
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// FEES
    //////////////////////////////////////////////////////////////////////////////////////

    function isFeeOperator(address _account) public view override returns (bool) {
        return owner == _account;
    }
}
