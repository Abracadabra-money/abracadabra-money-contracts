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

    uint256 public constant BIPS = 10_000;

    mapping(address => bool) public operators;
    mapping(BaseStrategy => uint64) public lastExecution;

    constructor() {
        operators[msg.sender] = true;
    }

    modifier onlyOperators() {
        if (!operators[msg.sender]) {
            revert NotAllowedOperator();
        }
        _;
    }

    function _run(
        BaseStrategy strategy,
        uint256 maxBentoBoxAmountIncreaseInBips,
        uint256 maxBentoBoxChangeAmountInBips,
        bytes[] calldata calls
    ) private {
        IBentoBoxV1 bentoBox = strategy.bentoBox();
        IERC20 strategyToken = strategy.strategyToken();
        uint128 totals = bentoBox.totals(strategyToken).elastic;
        uint256 maxBalance = totals + ((totals * BIPS) / maxBentoBoxAmountIncreaseInBips);
        uint256 maxChangeAmount = (maxBalance * maxBentoBoxChangeAmountInBips) / BIPS;
        strategy.safeHarvest(maxBalance, true, maxChangeAmount, false);

        for (uint256 i = 0; i < calls.length; i++) {
            address(strategy).functionCall(calls[i], "call failed");
        }

        strategy.safeHarvest(maxBalance, true, 0, false);
        lastExecution[strategy] = uint64(block.timestamp);
    }

    function runMultiple(
        BaseStrategy[] calldata strategy,
        uint256[] calldata maxBentoBoxAmountIncreaseInBips,
        uint256[] calldata maxBentoBoxChangeAmountInBips,
        bytes[][] calldata calls
    ) external onlyOperators {
        for (uint256 i = 0; i < strategy.length; i++) {
            _run(strategy[i], maxBentoBoxAmountIncreaseInBips[i], maxBentoBoxChangeAmountInBips[i], calls[i]);
        }
    }

    function run(
        BaseStrategy strategy,
        uint256 maxBentoBoxAmountIncreaseInBips,
        uint256 maxBentoBoxChangeAmountInBips,
        bytes[] calldata calls
    ) external onlyOperators {
        _run(strategy, maxBentoBoxAmountIncreaseInBips, maxBentoBoxChangeAmountInBips, calls);
    }

    function setOperator(address operator, bool status) external onlyOwner {
        operators[operator] = status;
        emit OperatorChanged(operator, status);
    }
}
