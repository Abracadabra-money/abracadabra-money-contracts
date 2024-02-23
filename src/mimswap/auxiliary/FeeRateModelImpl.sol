// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {IFeeRateImpl} from "../interfaces/IFeeRateModel.sol";
import {Math} from "/mimswap/libraries/Math.sol";

contract FeeRateModelImpl {
    uint256 public MAX_FEE_RATE = 0.0005 ether; // 0.05%

    // 50% of the LP fee rate, up to MAX_FEE_RATE
    function getFeeRate(
        address /*pool*/,
        address /*trader*/,
        uint256 lpFeeRate
    ) external view returns (uint256 adjustedLpFeeRate, uint256 mtFeeRate) {
        mtFeeRate = Math.divCeil(lpFeeRate, 2);

        if (mtFeeRate > MAX_FEE_RATE) {
            mtFeeRate = MAX_FEE_RATE;
        }

        return (lpFeeRate - mtFeeRate, mtFeeRate);
    }
}
