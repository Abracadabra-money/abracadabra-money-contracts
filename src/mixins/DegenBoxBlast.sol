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
    function claimETHYields(uint256 amount) external;

    function claimTokenYields(address token, uint256 amount) external;

    function claimGasYields() external;

    function setTokenYieldEnabled(address token, bool enabled) external;
}

contract DegenBoxBlast is DegenBox, OperatableV3, FeeCollectable {
    using BoringMath for uint256;
    using BoringMath128 for uint128;
    using RebaseLibrary for Rebase;
    using BoringERC20 for IERC20;

    event LogBlastETHClaimed(uint256 amount);
    event LogBlastGasClaimed(uint256 amount);
    event LogBlastTokenClaimed(uint256 amount);
    event LogBlastYieldAdded(IERC20 indexed token, uint256 userAmount, uint256 feeAmount);
    event LogBlastTokenEnabled(IERC20Rebasing indexed token, bool previous, bool current);

    error ErrYieldTokenNotEnabled();

    IBlast constant BLAST_YIELD_PRECOMPILE = IBlast(0x4300000000000000000000000000000000000002);

    mapping(IERC20Rebasing => bool) public enabledYieldTokens;

    constructor(IERC20 _weth) DegenBox(_weth) {}

    //////////////////////////////////////////////////////////////////////////////////////
    /// OPERATORS
    //////////////////////////////////////////////////////////////////////////////////////

    function claimETHYields(uint256 amount) external onlyOperators {
        if (amount == type(uint256).max) {
            amount = BLAST_YIELD_PRECOMPILE.claimAllYield(address(this), address(this));
        } else {
            amount = BLAST_YIELD_PRECOMPILE.claimYield(address(this), address(this), amount);
        }

        emit LogBlastETHClaimed(amount);
        
        IWETH(address(wethToken)).deposit{value: amount}();
        _distributeYields(wethToken, amount);
    }

    function claimTokenYields(IERC20Rebasing token, uint256 amount) external onlyOperators {
        if (!enabledYieldTokens[token]) {
            revert ErrYieldTokenNotEnabled();
        }

        if (amount == type(uint256).max) {
            amount = token.getClaimableAmount(address(this));
        }

        amount = token.claim(address(this), amount);

        emit LogBlastTokenClaimed(amount);
        _distributeYields(IERC20(address(token)), amount);
    }

    function claimGasYields() external onlyOperators {
        uint256 amount = BLAST_YIELD_PRECOMPILE.claimAllGas(address(this), owner);

        emit LogBlastGasClaimed(amount);

        IWETH(address(wethToken)).deposit{value: amount}();
        _distributeYields(wethToken, amount);
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// ADMIN
    //////////////////////////////////////////////////////////////////////////////////////

    /// @notice Enable or disable the yield for a token
    /// Warning: When disabling a token, be sure to claim all the yields first
    function setTokenYieldEnabled(IERC20Rebasing token, bool enabled) external onlyOwner {
        emit LogBlastTokenEnabled(token, enabledYieldTokens[token], enabled);
        enabledYieldTokens[token] = enabled;

        if (enabled) {
            IERC20Rebasing(token).configure(YieldMode.CLAIMABLE);
        } else {
            IERC20Rebasing(token).configure(YieldMode.VOID);
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

        uint256 totalElastic = totals[token].elastic;

        totalElastic = totalElastic.add(userAmount);
        totals[token].elastic = totalElastic.to128();

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
