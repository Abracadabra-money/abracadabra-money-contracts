pragma solidity ^0.8.16;

import "interfaces/IAggregator.sol";

contract OracleMock is IAggregator {
    uint8 public override decimals = 18;
    int256 public override latestAnswer = 0;
    
    function setPrice(int256 price) public {
        latestAnswer = price;
    }

    function setDecimals(uint8 _decimals) public {
        decimals = _decimals;
    }

    function latestRoundData()
        external
        view
        returns (
            uint80,
            int256,
            uint256,
            uint256,
            uint80
        )
    {
        return (0, latestAnswer, 0, 0, 0);
    }
}
