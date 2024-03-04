// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2021 BoringCrypto - All rights reserved
pragma solidity >=0.8.0;

import {DegenBox} from "/DegenBox.sol";
import {BlastYields} from "/blast/libraries/BlastYields.sol";
import {BlastPoints} from "/blast/libraries/BlastPoints.sol";
import {BlastTokenRegistry} from "/blast/BlastTokenRegistry.sol";
import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {OperatableV3} from "mixins/OperatableV3.sol";
import {IWETH} from "interfaces/IWETH.sol";

contract BlastBox is DegenBox, OperatableV3 {
    event LogTokenDepositEnabled(address indexed token, bool enabled);
    event LogFeeToChanged(address indexed feeTo);

    error ErrZeroAddress();
    error ErrUnsupportedToken();

    BlastTokenRegistry public immutable registry;
    mapping(address => bool) public enabledTokens;
    address public feeTo;

    constructor(IERC20 weth_, BlastTokenRegistry registry_, address feeTo_) DegenBox(weth_) {
        if (feeTo_ == address(0)) {
            revert ErrZeroAddress();
        }
        if (address(registry_) == address(0)) {
            revert ErrZeroAddress();
        }

        registry = registry_;
        feeTo = feeTo_;
    }

    function _onBeforeDeposit(
        IERC20 token,
        address /*from*/,
        address /*to*/,
        uint256 /*amount*/,
        uint256 /*share*/
    ) internal view override {
        if (!enabledTokens[address(token)]) {
            revert ErrUnsupportedToken();
        }
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// OPERATORS
    //////////////////////////////////////////////////////////////////////////////////////

    function claimGasYields() external onlyOperators returns (uint256) {
        return BlastYields.claimMaxGasYields(feeTo);
    }

    function claimTokenYields(address token_) external onlyOperators returns (uint256 amount) {
        if (!registry.nativeYieldTokens(token_)) {
            revert ErrUnsupportedToken();
        }

        amount = BlastYields.claimAllTokenYields(token_, feeTo);
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// ADMIN
    //////////////////////////////////////////////////////////////////////////////////////

    function callBlastPrecompile(bytes calldata data) external onlyOwner {
        BlastYields.callPrecompile(data);
    }

    function setFeeTo(address feeTo_) external onlyOwner {
        if (feeTo_ == address(0)) {
            revert ErrZeroAddress();
        }

        feeTo = feeTo_;
        emit LogFeeToChanged(feeTo_);
    }

    function setTokenEnabled(address token, bool enabled) external onlyOwner {
        enabledTokens[token] = enabled;

        // enable native yields if token is recognized
        // no matter if it's enabled or not
        if (registry.nativeYieldTokens(token)) {
            BlastYields.enableTokenClaimable(token);
        }

        emit LogTokenDepositEnabled(token, enabled);
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// INTERNALS
    //////////////////////////////////////////////////////////////////////////////////////

    /// @dev Called on DegenBox's constructor
    function _configure() internal override {
        BlastYields.configureDefaultClaimables(address(this));
        BlastPoints.configure();
    }

    function isOwner(address _account) internal view override returns (bool) {
        return owner == _account;
    }
}
