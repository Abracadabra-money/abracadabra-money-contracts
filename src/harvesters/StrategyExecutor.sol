// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/interfaces/IERC20.sol";
import "BoringSolidity/BoringOwnable.sol";
import "OpenZeppelin/utils/Address.sol";
import "strategies/BaseStrategy.sol";
import "interfaces/IBentoBoxV1.sol";

contract StrategyExecutor is BoringOwnable {
    using Address for address;
    event OperatorChanged(address indexed, bool);
    error NotAllowedOperator();

    mapping(address => bool) public operators;
    uint256 public lastExecution;

    constructor() {
        operators[msg.sender] = true;
    }

    modifier onlyOperators() {
        if (!operators[msg.sender]) {
            revert NotAllowedOperator();
        }
        _;
    }

    function run(
        BaseStrategy strategy,
        uint256 maxBentoBoxAmountIncreasePercent,
        uint256 maxBentoBoxChangeAmountPercent,
        bytes[] calldata calls
    ) external onlyOperators {
        IBentoBoxV1 bentoBox = strategy.bentoBox();
        IERC20 strategyToken = strategy.strategyToken();
        uint128 totals = bentoBox.totals(strategyToken).elastic;
        uint256 maxBalance = totals + ((totals * 100) / maxBentoBoxAmountIncreasePercent);
        uint256 maxChangeAmount = (maxBalance * maxBentoBoxChangeAmountPercent) / 100;
        strategy.safeHarvest(maxBalance, true, maxChangeAmount, false);

        for (uint256 i = 0; i < calls.length; i++) {
            address(strategy).functionCall(calls[i], "call failed");
        }

        strategy.safeHarvest(maxBalance, true, 0, false);
        lastExecution = block.timestamp;
    }

    function setOperator(address operator, bool status) external onlyOwner {
        operators[operator] = status;
        emit OperatorChanged(operator, status);
    }
}
