// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IAggregator} from "interfaces/IAggregator.sol";
import {IWitnetPriceRouter} from "interfaces/IWitnetPriceRouter.sol";

/// @title WitnetAggregator
/// @notice Wraps witnet price router in an aggregator interface
contract WitnetAggregator is IAggregator {
    IWitnetPriceRouter public immutable router;
    bytes4 public immutable id;
    uint8 public immutable _decimals;

    constructor(bytes4 _id, address _router, uint8 __decimals) {
        id = _id;
        router = IWitnetPriceRouter(_router);
        _decimals = __decimals;
    }

    function decimals() external view override returns (uint8) {
        return _decimals;
    }

    function latestAnswer() external view returns (int256 _price) {
        (_price, , ) = router.valueFor(id);
    }

    function latestRoundData() public view returns (uint80, int256 answer, uint256, uint256 updatedAt, uint80) {
        (answer, updatedAt, ) = router.valueFor(id);
        return (0, answer, 0, updatedAt, 0);
    }
}
