/*

    Copyright 2020 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity >=0.8.0;

import {Owned} from "solmate/auth/Owned.sol";
import {IFeeRateImpl} from "../interfaces/IFeeRateModel.sol";

contract FeeRateModel is Owned {
    event LogParametersChanged(address indexed feeRateImpl, uint256 defaultFeeRate);
    event LogMaintainerChanged(address indexed maintainer);

    address public maintainer;
    address public feeRateImpl;
    uint256 public defaultMtFeeRate;

    constructor(address maintainer_, uint _defaultMtRate, address _owner) Owned(_owner) {
        maintainer = maintainer_;
        defaultMtFeeRate = _defaultMtRate;
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// VIEWS
    //////////////////////////////////////////////////////////////////////////////////////

    function getFeeRate(address trader, uint256 lpFeeRate) external view returns (uint256 adjustedLpFeeRate, uint256 mtFeeRate) {
        if (feeRateImpl == address(0)) {
            return (lpFeeRate, defaultMtFeeRate);
        }

        return IFeeRateImpl(feeRateImpl).getFeeRate(msg.sender, trader, lpFeeRate);
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// ADMIN
    //////////////////////////////////////////////////////////////////////////////////////
    
    function setMaintainer(address _maintainer) external onlyOwner {
        maintainer = _maintainer;
        emit LogMaintainerChanged(_maintainer);
    }

    /// @notice Set the fee rate implementation and default fee rate
    /// @param _feeRateImpl The address of the fee rate implementation, use address(0) to disable and use defaultFeeRate
    /// @param _defaultRate The default fee rate used when feeRateImpl is address(0)
    function setParameters(address _feeRateImpl, uint _defaultRate) public onlyOwner {
        feeRateImpl = _feeRateImpl;
        defaultMtFeeRate = _defaultRate;
        emit LogParametersChanged(_feeRateImpl, _defaultRate);
    }
}
