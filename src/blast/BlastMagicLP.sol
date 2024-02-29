// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.0;

import {MagicLP} from "/mimswap/MagicLP.sol";
import {BlastYields} from "/blast/libraries/BlastYields.sol";
import {BlastPoints} from "/blast/libraries/BlastPoints.sol";
import {BlastTokenRegistry} from "/blast/BlastTokenRegistry.sol";

contract BlastMagicLP is MagicLP {
    event LogFeeToChanged(address indexed feeTo);
    event LogOperatorChanged(address indexed, bool);
    event LogYieldClaimed(uint256 gasAmount, uint256 nativeAmount, uint256 token0Amount, uint256 token1Amount);

    error ErrNotAllowedImplementationOperator();

    BlastTokenRegistry public immutable registry;

    /// @dev Implementation storage
    address public feeTo;
    mapping(address => bool) public operators;

    constructor(BlastTokenRegistry registry_, address feeTo_, address owner_) MagicLP(owner_) {
        if (feeTo_ == address(0)) {
            revert ErrZeroAddress();
        }
        if (address(registry_) == address(0)) {
            revert ErrZeroAddress();
        }

        registry = registry_;
        feeTo = feeTo_;
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
        address feeTo_ = BlastMagicLP(address(implementation)).feeTo();

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

        feeTo = feeTo_;
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
        BlastPoints.configure();
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
        if (!BlastMagicLP(address(implementation)).operators(msg.sender) && msg.sender != implementation.owner()) {
            revert ErrNotAllowedImplementationOperator();
        }
        _;
    }
}
