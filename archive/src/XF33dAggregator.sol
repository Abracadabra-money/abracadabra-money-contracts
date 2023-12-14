// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "interfaces/IAggregator.sol";
import "interfaces/IXF33dMultiAggregator.sol";

contract XF33dAggregator is IAggregator {
    error NegativePriceFeed();

    IXF33dMultiAggregator public immutable xf33dMultiAggregator;
    bytes32 public immutable feedHash;

    constructor(IXF33dMultiAggregator _xf33dMultiAggregator, bytes32 _feedHash) {
        xf33dMultiAggregator = _xf33dMultiAggregator;
        feedHash = _feedHash;
    }

    function decimals() external view override returns (uint8) {
        return xf33dMultiAggregator.decimals(feedHash);
    }

    function latestAnswer() public view override returns (int256 answer) {
        int256 price = xf33dMultiAggregator.latestAnswer(feedHash);

        if (price < 0) {
            revert NegativePriceFeed();
        }

        return price;
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return xf33dMultiAggregator.latestRoundData(feedHash);
    }
}
