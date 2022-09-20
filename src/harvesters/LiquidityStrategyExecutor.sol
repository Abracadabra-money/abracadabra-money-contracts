// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/interfaces/IERC20.sol";
import "BoringSolidity/BoringOwnable.sol";
import "strategies/LiquityStabilityPoolStrategy.sol";
import "interfaces/IBentoBoxV1.sol";

contract LiquityStrategyExecutor is BoringOwnable {
    event SetVerified(address, bool);

    uint256 public constant BIPS = 10_000;
    mapping(address => bool) public verified;
    uint256 public lastExecution;

    struct SwapRewardParam {
        uint256 amountOutMin;
        IERC20 rewardToken;
        bytes swapperData;
    }

    modifier onlyVerified() {
        require(verified[msg.sender], "Only verified operators");
        _;
    }

    function run(
        LiquityStabilityPoolStrategy strategy,
        uint256 maxBentoBoxAmountIncreaseInBips,
        SwapRewardParam[] calldata swapParams
    ) external onlyVerified {
        IBentoBoxV1 bentoBox = strategy.bentoBox();
        IERC20 strategyToken = strategy.strategyToken();
        uint128 totals = bentoBox.totals(strategyToken).elastic;
        uint256 maxBalance = totals + ((totals * BIPS) / maxBentoBoxAmountIncreaseInBips);

        strategy.safeHarvest(maxBalance, true, 0, false);

        for (uint256 i = 0; i < swapParams.length; i++) {
            strategy.swapRewards(swapParams[i].amountOutMin, swapParams[i].rewardToken, swapParams[i].swapperData);
        }

        strategy.safeHarvest(maxBalance, true, 0, false);

        lastExecution = block.timestamp;
    }

    function setVerified(address operator, bool status) external onlyOwner {
        verified[operator] = status;
        emit SetVerified(operator, status);
    }
}
