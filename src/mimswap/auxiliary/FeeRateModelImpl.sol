// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {IFeeRateImpl} from "../interfaces/IFeeRateModel.sol";
import {Math} from "/mimswap/libraries/Math.sol";

contract FeeRateModelImpl {
    // 50% of the LP fee rate
    function getFeeRate(
        address /*pool*/,
        address /*trader*/,
        uint256 lpFeeRate
    ) external pure returns (uint256 adjustedLpFeeRate, uint256 mtFeeRate) {
        mtFeeRate = Math.divCeil(lpFeeRate, 2);
        return (lpFeeRate - mtFeeRate, mtFeeRate);
    }
}
