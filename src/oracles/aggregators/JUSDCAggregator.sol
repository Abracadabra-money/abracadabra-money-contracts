// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC4626} from "interfaces/IERC4626.sol";
import {IAggregator} from "interfaces/IAggregator.sol";

contract JUSDCAggregator is IAggregator {
    IERC4626 public immutable vault;
    IAggregator public immutable aggregator;

    constructor(IERC4626 _vault, IAggregator _aggregator) {
        assert(_aggregator.decimals() == 8);
        vault = _vault;
        aggregator = _aggregator;
    }

    function decimals() external view returns (uint8) {
        return vault.decimals();
    }

    function latestAnswer() public view override returns (int256) {
        return int256(vault.previewRedeem(uint256(aggregator.latestAnswer()) * 1e10));
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (0, latestAnswer(), 0, 0, 0);
    }
}
