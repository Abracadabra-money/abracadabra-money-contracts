/*

    Copyright 2020 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity >=0.8.0;

import {Owned} from "solmate/auth/Owned.sol";
import {IFeeRateImpl} from "../interfaces/IFeeRateModel.sol";

contract FeeRateModel is Owned {
    event LogParametersChanged(address indexed feeRateImpl, uint256 defaultFeeRate);

    address public feeRateImpl;
    uint256 public defaultFeeRate;

    constructor(uint _defaultRate, address _owner) Owned(_owner) {
        defaultFeeRate = _defaultRate;
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// VIEWS
    //////////////////////////////////////////////////////////////////////////////////////

    function getFeeRate(address trader) external view returns (uint256) {
        if (feeRateImpl == address(0)) {
            return defaultFeeRate;
        }

        return IFeeRateImpl(feeRateImpl).getFeeRate(msg.sender, trader);
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// ADMIN
    //////////////////////////////////////////////////////////////////////////////////////

    /// @notice Set the fee rate implementation and default fee rate
    /// @param _feeRateImpl The address of the fee rate implementation, use address(0) to disable and use defaultFeeRate
    /// @param _defaultRate The default fee rate used when feeRateImpl is address(0)
    function setParameters(address _feeRateImpl, uint _defaultRate) public onlyOwner {
        feeRateImpl = _feeRateImpl;
        defaultFeeRate = _defaultRate;
        emit LogParametersChanged(_feeRateImpl, _defaultRate);
    }
}
