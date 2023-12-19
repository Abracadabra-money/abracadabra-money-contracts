// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {Address} from "openzeppelin-contracts/utils/Address.sol";
import {BaseStrategy} from "strategies/BaseStrategy.sol";
import {IBentoBoxV1} from "interfaces/IBentoBoxV1.sol";
import {OperatableV2} from "mixins/OperatableV2.sol";

contract StrategyExecutor is OperatableV2 {
    using Address for address;

    uint256 public constant BIPS = 10_000;

    mapping(BaseStrategy => uint64) public lastExecution;

    constructor(address _owner) OperatableV2(_owner) {}

    function _run(
        BaseStrategy strategy,
        uint256 maxBentoBoxAmountIncreaseInBips,
        uint256 maxBentoBoxChangeAmountInBips,
        address[] calldata callees,
        bytes[] calldata data,
        bool postRebalanceEnabled
    ) private {
        IBentoBoxV1 bentoBox = strategy.bentoBox();
        IERC20 strategyToken = strategy.strategyToken();
        uint128 totals = bentoBox.totals(strategyToken).elastic;
        uint256 maxBalance = totals + ((totals * BIPS) / maxBentoBoxAmountIncreaseInBips);
        uint256 maxChangeAmount = (maxBalance * maxBentoBoxChangeAmountInBips) / BIPS;
        strategy.safeHarvest(maxBalance, true, maxChangeAmount, false);

        for (uint256 i = 0; i < data.length; i++) {
            callees[i].functionCall(data[i], "call failed");
        }

        // useful when the previous function calls adds back strategy token to rebalance
        if (postRebalanceEnabled) {
            strategy.safeHarvest(maxBalance, true, 0, false);
        }

        lastExecution[strategy] = uint64(block.timestamp);
    }

    function runMultiple(
        BaseStrategy[] calldata strategy,
        uint256[] calldata maxBentoBoxAmountIncreaseInBips,
        uint256[] calldata maxBentoBoxChangeAmountInBips,
        address[][] calldata callees,
        bytes[][] calldata data,
        bool[] calldata postRebalanceEnabled
    ) external onlyOperators {
        for (uint256 i = 0; i < strategy.length; i++) {
            _run(
                strategy[i],
                maxBentoBoxAmountIncreaseInBips[i],
                maxBentoBoxChangeAmountInBips[i],
                callees[i],
                data[i],
                postRebalanceEnabled[i]
            );
        }
    }

    function run(
        BaseStrategy strategy,
        uint256 maxBentoBoxAmountIncreaseInBips,
        uint256 maxBentoBoxChangeAmountInBips,
        address[] calldata callees,
        bytes[] calldata calls,
        bool postRebalanceEnabled
    ) external onlyOperators {
        _run(strategy, maxBentoBoxAmountIncreaseInBips, maxBentoBoxChangeAmountInBips, callees, calls, postRebalanceEnabled);
    }
}
