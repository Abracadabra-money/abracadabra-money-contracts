// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ERC20WithSupply} from "BoringSolidity/ERC20.sol";
import "BoringSolidity/libraries/BoringERC20.sol";
import "BoringSolidity/BoringOwnable.sol";
import "OpenZeppelin/utils/Address.sol";
import "forge-std/console2.sol";

contract GmxGlpWrapperData is BoringOwnable, ERC20WithSupply {
    error ErrNotStrategyExecutor(address);

    IERC20 public sGlp;
    string public name;
    string public symbol;
    address public rewardHandler;
    mapping(address => bool) public strategyExecutors;

    modifier onlyStrategyExecutor() {
        if (msg.sender != owner && !strategyExecutors[msg.sender]) {
            revert ErrNotStrategyExecutor(msg.sender);
        }
        _;
    }
}

contract GmxGlpWrapper is GmxGlpWrapperData {
    using BoringERC20 for IERC20;

    event LogRewardHandlerChanged(address indexed previous, address indexed current);
    event LogStrategyExecutorChanged(address indexed executor, bool allowed);
    event LogStakedGlpChanged(IERC20 indexed previous, IERC20 indexed current);

    constructor(
        IERC20 _sGlp,
        string memory _name,
        string memory _symbol
    ) {
        name = _name;
        symbol = _symbol;
        sGlp = _sGlp;
    }

    function decimals() external view returns (uint8) {
        return sGlp.safeDecimals();
    }

    function _enter(uint256 amount, address recipient) internal returns (uint256 shares) {
        shares = toShares(amount);
        _mint(recipient, shares);
        sGlp.safeTransferFrom(msg.sender, address(this), amount);
    }

    function _leave(uint256 shares, address recipient) internal returns (uint256 amount) {
        amount = toAmount(shares);
        _burn(msg.sender, shares);
        sGlp.safeTransfer(recipient, amount);
    }

    function enter(uint256 amount) external returns (uint256 shares) {
        return _enter(amount, msg.sender);
    }

    function enterFor(uint256 amount, address recipient) external returns (uint256 shares) {
        return _enter(amount, recipient);
    }

    function leave(uint256 shares) external returns (uint256 amount) {
        return _leave(shares, msg.sender);
    }

    function leaveTo(uint256 shares, address recipient) external returns (uint256 amount) {
        return _leave(shares, recipient);
    }

    function leaveAll() external returns (uint256 amount) {
        return _leave(balanceOf[msg.sender], msg.sender);
    }

    function leaveAllTo(address recipient) external returns (uint256 amount) {
        return _leave(balanceOf[msg.sender], recipient);
    }

    function toAmount(uint256 shares) public view returns (uint256) {
        uint256 totalsGlp = sGlp.balanceOf(address(this));
        return (totalSupply == 0 || totalsGlp == 0) ? shares : (shares * totalsGlp) / totalSupply;
    }

    function toShares(uint256 amount) public view returns (uint256) {
        uint256 totalsGlp = sGlp.balanceOf(address(this));
        return (totalSupply == 0 || totalsGlp == 0) ? amount : (amount * totalSupply) / totalsGlp;
    }

    function setStrategyExecutor(address executor, bool value) external onlyOwner {
        strategyExecutors[executor] = value;
        emit LogStrategyExecutorChanged(executor, value);
    }

    function setRewardHandler(address _rewardHandler) external onlyOwner {
        emit LogRewardHandlerChanged(rewardHandler, _rewardHandler);
        rewardHandler = _rewardHandler;
    }

    function setStakedGlp(IERC20 _sGlp) external onlyOwner {
        emit LogStakedGlpChanged(sGlp, _sGlp);
        sGlp = _sGlp;
    }

    // Forward unknown function calls to the reward handler.
    fallback() external {
        _delegate(rewardHandler);
    }

    /**
     * From https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/proxy/Proxy.sol
     *
     * @dev Delegates the current call to `implementation`.
     *
     * This function does not return to its internal call site, it will return directly to the external caller.
     */
    function _delegate(address implementation) private {
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall returns 0 on error.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }
}
