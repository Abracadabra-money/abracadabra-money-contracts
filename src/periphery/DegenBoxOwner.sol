// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/ERC20.sol";
import "BoringSolidity/BoringOwnable.sol";
import "OpenZeppelin/utils/Address.sol";
import "interfaces/IBentoBoxOwner.sol";
import "interfaces/IBentoBoxV1.sol";

contract DegenBoxOwner is BoringOwnable, IBentoBoxOwner {
    error ErrNotOperator(address operator);

    event LogOperatorChanged(address indexed operator, bool previous, bool current);
    event LogDegenBoxChanged(IBentoBoxV1 indexed previous, IBentoBoxV1 indexed current);

    IBentoBoxV1 public degenBox;
    mapping(address => bool) public strategyOperators;
    mapping(address => bool) public operators;

    modifier onlyOperators() {
        if (msg.sender != owner && !operators[msg.sender]) {
            revert ErrNotOperator(msg.sender);
        }
        _;
    }

    // operators are also strategy operators by default
    modifier onlyStrategyOperators() {
        if (msg.sender != owner && !strategyOperators[msg.sender] && !operators[msg.sender]) {
            revert ErrNotOperator(msg.sender);
        }
        _;
    }

    function setStrategyTargetPercentageAndRebalance(IERC20 token, uint64 targetPercentage) external onlyStrategyOperators {
        //uint256 maxChangeAmount = (maxBalance * maxBentoBoxChangeAmountInBips) / BIPS;
    }

    function setStrategyTargetPercentage(IERC20 token, uint64 targetPercentage) external onlyOperators {
        degenBox.setStrategyTargetPercentage(token, targetPercentage);
    }

    function whitelistMasterContract(address masterContract, bool approved) external onlyOperators {
        degenBox.whitelistMasterContract(masterContract, approved);
    }

    function setOperator(address operator, bool enabled) external onlyOwner {
        emit LogOperatorChanged(operator, operators[operator], enabled);
        operators[operator] = enabled;
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
