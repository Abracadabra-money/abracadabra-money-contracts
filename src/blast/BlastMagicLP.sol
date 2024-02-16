// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.0;

import {MagicLP} from "/mimswap/MagicLP.sol";
import {BlastYields} from "/blast/libraries/BlastYields.sol";
import {BlastTokenRegistry} from "/blast/BlastTokenRegistry.sol";
import {Owned} from "solmate/auth/Owned.sol";

contract BlastMagicLP is MagicLP, Owned {
    event LogFeeToChanged(address indexed feeTo);
    event LogOperatorChanged(address indexed, bool);
    event LogYieldClaimed(uint256 gasAmount, uint256 nativeAmount, uint256 token0Amount, uint256 token1Amount);

    error ErrNotAllowedImplementationOperator();
    error ErrNotImplementationOwner();
    error ErrNotImplementation();
    error ErrNotClone();

    BlastMagicLP public immutable implementation;
    BlastTokenRegistry public immutable registry;

    /// @dev Implementation storage
    address public feeTo;
    mapping(address => bool) public operators;

    constructor(BlastTokenRegistry registry_, address feeTo_, address owner_) Owned(owner_) {
        if (feeTo_ == address(0)) {
            revert ErrZeroAddress();
        }
        if (address(registry_) == address(0)) {
            revert ErrZeroAddress();
        }

        registry = registry_;
        feeTo = feeTo_;
        implementation = this;
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// VIEWS
    //////////////////////////////////////////////////////////////////////////////////////

    function version() external pure override returns (string memory) {
        return "BlastMagicLP 1.0.0";
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// OPERATORS / CLONES ONLY
    //////////////////////////////////////////////////////////////////////////////////////

    function claimYields()
        external
        onlyClones
        onlyImplementationOperators
        returns (uint256 gasAmount, uint256 nativeAmount, uint256 token0Amount, uint256 token1Amount)
    {
        address feeTo_ = implementation.feeTo();

        gasAmount = BlastYields.claimAllGasYields(feeTo_);
        nativeAmount = BlastYields.claimAllNativeYields(feeTo_);

        if (registry.nativeYieldTokens(_BASE_TOKEN_)) {
            token0Amount = BlastYields.claimAllTokenYields(_BASE_TOKEN_, feeTo_);
        }
        if (registry.nativeYieldTokens(_QUOTE_TOKEN_)) {
            token1Amount = BlastYields.claimAllTokenYields(_QUOTE_TOKEN_, feeTo_);
        }
    }

    function updateTokenClaimables() external onlyClones onlyImplementationOperators {
        _updateTokenClaimables();
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// ADMIN / IMPLEMENTATION ONLY
    //////////////////////////////////////////////////////////////////////////////////////

    function setFeeTo(address feeTo_) external onlyImplementation onlyImplementationOwner {
        if (feeTo_ == address(0)) {
            revert ErrZeroAddress();
        }

        feeTo_ = feeTo_;
        emit LogFeeToChanged(feeTo_);
    }

    function setOperator(address operator, bool status) external onlyImplementation onlyImplementationOwner {
        operators[operator] = status;
        emit LogOperatorChanged(operator, status);
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// INTERNALS
    //////////////////////////////////////////////////////////////////////////////////////

    function _afterInitialized() internal override {
        BlastYields.configureDefaultClaimables(address(this));
        _updateTokenClaimables();
    }

    function _updateTokenClaimables() internal {
        if (registry.nativeYieldTokens(_BASE_TOKEN_)) {
            BlastYields.enableTokenClaimable(_BASE_TOKEN_);
        }

        if (registry.nativeYieldTokens(_QUOTE_TOKEN_)) {
            BlastYields.enableTokenClaimable(_QUOTE_TOKEN_);
        }
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// MODIFIERS
    //////////////////////////////////////////////////////////////////////////////////////

    modifier onlyImplementationOperators() {
        if (!implementation.operators(msg.sender) && msg.sender != implementation.owner()) {
            revert ErrNotAllowedImplementationOperator();
        }
        _;
    }

    modifier onlyImplementationOwner() {
        if (msg.sender != implementation.owner()) {
            revert ErrNotImplementationOwner();
        }
        _;
    }

    modifier onlyClones() {
        if (address(this) == address(implementation)) {
            revert ErrNotClone();
        }
        _;
    }

    modifier onlyImplementation() {
        if (address(this) != address(implementation)) {
            revert ErrNotImplementation();
        }
        _;
    }
}
