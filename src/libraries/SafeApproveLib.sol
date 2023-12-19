// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";

library SafeApproveLib {
    error ErrApproveFailed();
    error ErrApproveFailedWithData(bytes data);

    function safeApprove(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = address(token).call(abi.encodeCall(IERC20.approve, (to, value)));
        if (!success) {
            revert ErrApproveFailed();
        }
        if (data.length != 0 && !abi.decode(data, (bool))) {
            revert ErrApproveFailedWithData(data);
        }
    }
}