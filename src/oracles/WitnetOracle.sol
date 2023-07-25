// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "interfaces/IAggregator.sol";

interface IWitnetPriceRouter {
     /// Returns the ERC-165-compliant price feed contract currently serving 
    /// updates on the given currency pair.
    function valueFor(bytes32 _erc2362id) external view returns (int256,uint256,uint256);
}

contract WitnetOracle is IAggregator {
    IWitnetPriceRouter constant public router = IWitnetPriceRouter(0xD39D4d972C7E166856c4eb29E54D3548B4597F53);
    bytes4 constant public KAVA_USD_ID = bytes4(0xde77dd55);

    function decimals() external pure returns (uint8) {
        return 6;
    }

    
    /// Returns the KAVA / USD price (6 decimals), ultimately provided by the Witnet oracle.
    function latestAnswer() external view returns (int256 _price) {
        (_price,,) = router.valueFor(KAVA_USD_ID);
    }
    
    /// Returns the KAVA / USD price (6 decimals) & time updated At, ultimately provided by the Witnet oracle.
    function latestRoundData() public view returns (uint80, int256 answer,uint256,uint256 updatedAt,uint80) {
        (answer,updatedAt,) = router.valueFor(KAVA_USD_ID);
        return(0, answer, 0, updatedAt, 0);
    }
}