// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {FixedPriceOracle} from "/oracles/FixedPriceOracle.sol";

contract PausableFixedPriceOracle is FixedPriceOracle {
    event LogPaused(bool _paused);

    error ErrPaused();

    bool public paused;

    constructor(string memory _desc, uint256 _price, uint8 _decimals, bool _paused) FixedPriceOracle(_desc, _price, _decimals) {
        paused = _paused;
    }

    function _get() override internal view returns (uint256) {
        if (paused) revert ErrPaused();
        return price;
    }

    function pause(bool _paused) external onlyOwner {
        paused = _paused;
        emit LogPaused(_paused);
    }
}
