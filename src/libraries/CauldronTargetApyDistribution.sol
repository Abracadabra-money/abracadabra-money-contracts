// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "interfaces/ICauldronV2.sol";
import "interfaces/IBentoBoxV1.sol";

struct CauldronTargetApyDistributionItem {
    ICauldronV2 cauldron;
    address recipient;
    uint256 targetApyPerSecond;
    uint64 lastDistribution;
    // caching
    IOracle oracle;
    bytes oracleData;
    IBentoBoxV1 degenBox;
    IERC20 collateral;
}

enum SetDistributionInfoRetVal {
    ADDED,
    SET,
    REMOVED
}

/**
 * @notice Handle proportionnal distribution with target apy and the remaining.
 */
library CauldronTargetApyDistribution {
    error ErrInvalidTargetApy(uint256);
    error ErrAdjustedDistributionAmountTooHigh(uint256 from, uint256 to);

    function setDistributionInfo(
        CauldronTargetApyDistributionItem[] storage items,
        ICauldronV2 _cauldron,
        address _recipient,
        uint256 _targetApyBips
    ) internal returns (SetDistributionInfoRetVal) {
        if (_targetApyBips > 10_000) {
            revert ErrInvalidTargetApy(_targetApyBips);
        }

        int256 index = findDistributionInfoByRecipient(items, _recipient);
        if (index >= 0) {
            if (_targetApyBips > 0) {
                items[uint256(index)].targetApyPerSecond = (_targetApyBips * 1e18) / 365 days;
                return (SetDistributionInfoRetVal.SET);
            } else {
                items[uint256(index)] = items[items.length - 1];
                items.pop();
                return (SetDistributionInfoRetVal.REMOVED);
            }
        } else if (_targetApyBips > 0) {
            items.push(
                CauldronTargetApyDistributionItem({
                    cauldron: _cauldron,
                    recipient: _recipient,
                    targetApyPerSecond: (_targetApyBips * 1e18) / 365 days,
                    lastDistribution: uint64(block.timestamp),
                    degenBox: IBentoBoxV1(_cauldron.bentoBox()),
                    collateral: _cauldron.collateral(),
                    oracle: _cauldron.oracle(),
                    oracleData: _cauldron.oracleData()
                })
            );
            return (SetDistributionInfoRetVal.SET);
        }

        revert ErrInvalidTargetApy(_targetApyBips);
    }

    function findDistributionInfoByRecipient(CauldronTargetApyDistributionItem[] storage items, address recipient)
        internal
        view
        returns (int256)
    {
        for (uint256 i = 0; i < items.length; i++) {
            if (items[i].recipient == recipient) {
                return int256(i);
            }
        }

        return -1;
    }

    /// @notice `previewDistribution` useful to know in advance how the distribution allocations is going to look like.
    /// I.g, When using an offchain resolver, one needs to know how much rewards are going to be obtained so that it's
    // easier to call 0x api with the right amount to swap and send a single tx with all the operations.
    function previewDistribution(
        CauldronTargetApyDistributionItem[] storage items,
        uint256 amountAvailableToDistribute,
        function(CauldronTargetApyDistributionItem memory, uint256) view returns (uint256) previewDistributeToRecipient
    ) internal view returns (uint256[] memory distributionAllocations, uint256 collectableFeeAmount) {
        distributionAllocations = new uint256[](items.length);

        // based on each distribution apy per second, the allocation of the current amount to be distributed.
        // this way amount distribution rate is controlled by each target apy and not all distributed
        // immediately
        uint256 idealTotalDistributionAllocation;

        // Gather all stats needed for the subsequent distribution
        for (uint256 i = 0; i < items.length; i++) {
            CauldronTargetApyDistributionItem memory info = items[i];

            uint64 timeElapsed = uint64(block.timestamp) - info.lastDistribution;

            if (timeElapsed == 0) {
                continue;
            }

            // compute the cauldron's total collateral share value in usd
            uint256 totalCollateralAmount = info.degenBox.toAmount(info.collateral, info.cauldron.totalCollateralShare(), false);
            uint256 totalCollateralShareValue = (totalCollateralAmount * 1e18) / info.oracle.peekSpot(info.oracleData);

            if (totalCollateralShareValue > 0) {
                // calculate how much to distribute to this recipient based on target apy per second versus how many time
                // has passed since the last distribution.
                distributionAllocations[i] = (info.targetApyPerSecond * totalCollateralShareValue * timeElapsed) / (10_000 * 1e18);
                idealTotalDistributionAllocation += distributionAllocations[i];
            }

            info.lastDistribution = uint64(block.timestamp);
        }

        if (idealTotalDistributionAllocation == 0) {
            return (distributionAllocations, 0);
        }

        uint256 effectiveTotalDistributionAllocation = idealTotalDistributionAllocation;

        // starving, demands is higher than produced yields
        if (effectiveTotalDistributionAllocation > amountAvailableToDistribute) {
            effectiveTotalDistributionAllocation = amountAvailableToDistribute;
        }

        // Prorata the distribution along every cauldron asked apy so that every cauldron share the allocated amount.
        // Otherwise it would be first come first serve and some cauldrons might not receive anything.
        for (uint256 i = 0; i < items.length; i++) {
            CauldronTargetApyDistributionItem memory info = items[i];

            // take a share of the total requested distribution amount, in case of starving, take
            // a proportionnal share of it.
            uint256 distributionAmount = (distributionAllocations[i] * effectiveTotalDistributionAllocation) /
                idealTotalDistributionAllocation;

            if (distributionAmount > amountAvailableToDistribute) {
                distributionAmount = amountAvailableToDistribute;
            }

            if (distributionAmount > 0) {
                // gives a chance to the recipient to adjust the distribution lower in case
                // it cannot consume it entirely
                uint256 adjustedDistributionAmount = previewDistributeToRecipient(info, distributionAmount);
                if (adjustedDistributionAmount > distributionAmount) {
                    revert ErrAdjustedDistributionAmountTooHigh(distributionAmount, adjustedDistributionAmount);
                }

                // reuse same slot for returning the final distribution amount
                distributionAllocations[i] = adjustedDistributionAmount;
                amountAvailableToDistribute -= adjustedDistributionAmount;
            } else {
                distributionAllocations[i] = 0;
            }
        }

        collectableFeeAmount = amountAvailableToDistribute;
    }

    /// @dev call previewDistribute to get the distributionAllocations parameter beforehand
    function distribute(
        CauldronTargetApyDistributionItem[] storage items,
        uint256[] memory distributionAllocations,
        bytes[] memory recipientSpecificData,
        function(CauldronTargetApyDistributionItem memory, uint256, bytes memory) distributeToRecipient
    ) internal {
        for (uint256 i = 0; i < items.length; i++) {
            CauldronTargetApyDistributionItem memory info = items[i];
            uint256 allocation = distributionAllocations[i];

            distributeToRecipient(info, allocation, recipientSpecificData[i]);
        }
    }
}
