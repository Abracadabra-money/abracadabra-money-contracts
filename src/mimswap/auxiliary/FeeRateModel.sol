/*

    Copyright 2020 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity >=0.8.0;

import {Owned} from "solmate/auth/Owned.sol";
import {IFeeRateImpl} from "../interfaces/IFeeRateModel.sol";

contract FeeRateModel is Owned {
    event LogImplementationChanged(address indexed implementation);
    event LogMaintainerChanged(address indexed maintainer);

    error ErrZeroAddress();

    address public maintainer;
    address public implementation;

    constructor(address maintainer_, address owner_) Owned(owner_) {
        if (maintainer_ == address(0)) {
            revert ErrZeroAddress();
        }

        maintainer = maintainer_;
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// VIEWS
    //////////////////////////////////////////////////////////////////////////////////////

    function getFeeRate(address trader, uint256 lpFeeRate) external view returns (uint256 adjustedLpFeeRate, uint256 mtFeeRate) {
        if (implementation == address(0)) {
            return (lpFeeRate, 0);
        }

        return IFeeRateImpl(implementation).getFeeRate(msg.sender, trader, lpFeeRate);
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// ADMIN
    //////////////////////////////////////////////////////////////////////////////////////

    function setMaintainer(address maintainer_) external onlyOwner {
        if (maintainer_ == address(0)) {
            revert ErrZeroAddress();
        }

        maintainer = maintainer_;
        emit LogMaintainerChanged(maintainer_);
    }

    /// @notice Set the fee rate implementation and default fee rate
    /// @param implementation_ The address of the fee rate implementation, use address(0) to disable
    function setImplementation(address implementation_) public onlyOwner {
        implementation = implementation_;
        emit LogImplementationChanged(implementation_);
    }
}
