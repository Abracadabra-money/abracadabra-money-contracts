// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/ERC20.sol";
import "BoringSolidity/BoringOwnable.sol";
import "interfaces/IBentoBoxOwner.sol";
import "interfaces/IBentoBoxV1.sol";

contract DegenBoxOwner is BoringOwnable, IBentoBoxOwner {
    error ErrNotOperator(address operator);
    error ErrNotStrategyRebalancer(address rebalancer);

    event LogOperatorChanged(address indexed operator, bool previous, bool current);
    event LogStrategyRebalancerChanged(address indexed rebalancer, bool previous, bool current);
    event LogDegenBoxChanged(IBentoBoxV1 indexed previous, IBentoBoxV1 indexed current);

    IBentoBoxV1 public degenBox;
    mapping(address => bool) public strategyRebalancers;
    mapping(address => bool) public operators;

    modifier onlyOperators() {
        if (msg.sender != owner && !operators[msg.sender]) {
            revert ErrNotOperator(msg.sender);
        }
        _;
    }

    constructor(IBentoBoxV1 _degenBox) {
        degenBox = _degenBox;
        emit LogDegenBoxChanged(IBentoBoxV1(address(0)), _degenBox);
    }

    modifier onlyStrategyRebalancers() {
        if (msg.sender != owner && !operators[msg.sender] && !strategyRebalancers[msg.sender]) {
            revert ErrNotStrategyRebalancer(msg.sender);
        }
        _;
    }

    function setStrategyTargetPercentage(IERC20 token, uint64 targetPercentage) external onlyOperators {
        degenBox.setStrategyTargetPercentage(token, targetPercentage);
    }

    function setStrategyTargetPercentageAndRebalance(IERC20 token, uint64 targetPercentage) external onlyStrategyRebalancers {
        degenBox.setStrategyTargetPercentage(token, targetPercentage);
        degenBox.harvest(token, true, type(uint256).max);
    }

    function setStrategy(IERC20 token, IStrategy newStrategy) public onlyOperators {
        degenBox.setStrategy(token, newStrategy);
    }

    function whitelistMasterContract(address masterContract, bool approved) external onlyOperators {
        degenBox.whitelistMasterContract(masterContract, approved);
    }

    function setOperator(address operator, bool enabled) external onlyOwner {
        emit LogOperatorChanged(operator, operators[operator], enabled);
        operators[operator] = enabled;
    }

    function setStrategyRebalancer(address rebalancer, bool enabled) external onlyOwner {
        emit LogStrategyRebalancerChanged(rebalancer, strategyRebalancers[rebalancer], enabled);
        strategyRebalancers[rebalancer] = enabled;
    }

    function setDegenBox(IBentoBoxV1 _degenBox) external onlyOwner {
        emit LogDegenBoxChanged(degenBox, _degenBox);
        degenBox = _degenBox;
    }

    function transferDegenBoxOwnership(address newOwner) external onlyOwner {
        degenBox.transferOwnership(newOwner, true, false);
    }

    /// low level execution for any other future added functions
    function execute(
        address to,
        uint256 value,
        bytes calldata data
    ) external onlyOwner returns (bool success, bytes memory result) {
        // solhint-disable-next-line avoid-low-level-calls
        (success, result) = to.call{value: value}(data);
    }
}
