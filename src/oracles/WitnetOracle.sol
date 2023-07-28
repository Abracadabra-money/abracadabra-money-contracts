// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "interfaces/IAggregator.sol";
import "interfaces/IWitnetPriceRouter.sol";

contract WitnetOracle is IAggregator {
    IWitnetPriceRouter immutable public router;
    bytes4 immutable public id;
    uint8 public immutable decimals;

    constructor(bytes4 _id, address _router, uint8 _decimals) {
        id = _id;
        router = IWitnetPriceRouter(_router);
        decimals = _decimals;
    }

    
    /// Returns the KAVA / USD price (6 decimals), ultimately provided by the Witnet oracle.
    function latestAnswer() external view returns (int256 _price) {
        (_price,,) = router.valueFor(id);
    }
    
    /// Returns the KAVA / USD price (6 decimals) & time updated At, ultimately provided by the Witnet oracle.
    function latestRoundData() public view returns (uint80, int256 answer,uint256,uint256 updatedAt,uint80) {
        (answer,updatedAt,) = router.valueFor(id);
        return(0, answer, 0, updatedAt, 0);
    }
}