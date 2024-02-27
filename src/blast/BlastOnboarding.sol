// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {Owned} from "solmate/auth/Owned.sol";
import {BlastYields} from "/blast/libraries/BlastYields.sol";
import {BlastTokenRegistry} from "/blast/BlastTokenRegistry.sol";
import {Proxy} from "openzeppelin-contracts/proxy/Proxy.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

contract BlastOnboardingData is Owned {
    error ErrZeroAddress();
    error ErrWrongState();
    error ErrUnsupportedToken();

    enum State {
        Idle,
        Opened,
        Closed
    }

    struct Balances {
        uint256 unlocked;
        uint256 locked;
        uint256 total;
    }

    State public state;
    address public bootstrapper;
    address public feeTo;
    BlastTokenRegistry public registry;

    // Global
    mapping(address token => bool) public supportedTokens;
    mapping(address token => Balances) public totals;
    mapping(address token => uint256 cap) public caps;

    // Per-user
    mapping(address user => mapping(address token => Balances)) public balances;

    modifier onlyState(State _state) {
        if (state != _state) {
            revert ErrWrongState();
        }
        _;
    }

    modifier onlySupportedTokens(address token) {
        if (!supportedTokens[token]) {
            revert ErrUnsupportedToken();
        }

        _;
    }

    constructor() Owned(msg.sender) {
        BlastYields.configureDefaultClaimables(address(this));
    }
}

contract BlastOnboarding is BlastOnboardingData, Proxy {
    using SafeTransferLib for address;

    event LogBootstrapperChanged(address bootstrapper);
    event LogTokenSupported(address token, bool supported);
    event LogDeposit(address user, address token, uint256 amount, bool lock);
    event LogLock(address user, address token, uint256 amount);
    event LogFeeToChanged(address indexed feeTo);
    event LogWithdraw(address user, address token, uint256 amount);
    event LogTokenCapChanged(address token, uint256 cap);
    event LogStateChange(State state);

    error ErrUnsupported();
    error ErrCapReached();

    receive() external payable override {
        revert ErrUnsupported();
    }

    constructor(BlastTokenRegistry registry_, address feeTo_) {
        registry = registry_;
        feeTo = feeTo_;
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// PUBLIC
    //////////////////////////////////////////////////////////////////////////////////////

    function deposit(address token, uint256 amount, bool lock_) external onlyState(State.Opened) onlySupportedTokens(token) {
        token.safeTransferFrom(msg.sender, address(this), amount);

        if (lock_) {
            totals[token].locked += amount;
            balances[msg.sender][token].locked += amount;
        } else {
            totals[token].unlocked += amount;
            balances[msg.sender][token].unlocked += amount;
        }

        totals[token].total += amount;

        if (caps[token] > 0 && totals[token].total > caps[token]) {
            revert ErrCapReached();
        }

        balances[msg.sender][token].total += amount;

        emit LogDeposit(msg.sender, token, amount, lock_);
    }

    function lock(address token, uint256 amount) external onlyState(State.Opened) onlySupportedTokens(token) {
        balances[msg.sender][token].unlocked -= amount;
        balances[msg.sender][token].locked += amount;

        emit LogLock(msg.sender, token, amount);
    }

    function withdraw(address token, uint256 amount) external onlySupportedTokens(token) {
        balances[msg.sender][token].unlocked -= amount;
        balances[msg.sender][token].total -= amount;
        totals[token].unlocked -= amount;
        totals[token].total -= amount;

        token.safeTransfer(msg.sender, amount);

        emit LogWithdraw(msg.sender, token, amount);
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// ADMIN
    //////////////////////////////////////////////////////////////////////////////////////

    function setFeeTo(address feeTo_) external onlyOwner {
        if (feeTo_ == address(0)) {
            revert ErrZeroAddress();
        }

        feeTo = feeTo_;
        emit LogFeeToChanged(feeTo_);
    }

    function claimYields(address[] memory tokens) external onlyOwner {
        BlastYields.claimAllGasYields(feeTo);
        BlastYields.claimAllNativeYields(feeTo);

        for (uint256 i = 0; i < tokens.length; i++) {
            if (!supportedTokens[tokens[i]]) {
                revert ErrUnsupportedToken();
            }
            if (registry.nativeYieldTokens(tokens[i])) {
                BlastYields.claimAllTokenYields(tokens[i], feeTo);
            }
        }
    }

    function setTokenSupported(address token, bool supported) external onlyOwner {
        supportedTokens[token] = supported;

        if (registry.nativeYieldTokens(token)) {
            BlastYields.enableTokenClaimable(token);
        }

        emit LogTokenSupported(token, supported);
    }

    function setTokenSupported(address token, uint256 cap) external onlyOwner onlySupportedTokens(token) {
        caps[token] = cap;
        emit LogTokenCapChanged(token, cap);
    }

    function setBootstrapper(address bootstrapper_) external onlyOwner {
        bootstrapper = bootstrapper_;
        emit LogBootstrapperChanged(bootstrapper_);
    }

    function open() external onlyOwner onlyState(State.Idle) {
        state = State.Opened;
        emit LogStateChange(State.Opened);
    }

    function close() external onlyOwner onlyState(State.Opened) {
        state = State.Closed;
        emit LogStateChange(State.Closed);
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// PROXY IMPLEMENTATION
    //////////////////////////////////////////////////////////////////////////////////////

    function _fallback() internal override {
        _delegate(_implementation());
    }

    function _implementation() internal view override returns (address) {
        return address(bootstrapper);
    }
}
