// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {OperatableV2} from "/mixins/OperatableV2.sol";
import {IJonesRouter} from "/interfaces/IJonesRouter.sol";

contract JUSDCWithdrawer is OperatableV2 {
    address public immutable router;

    constructor(address _router, address _owner) OperatableV2(_owner) {
        router = _router;
    }

    function withdraw(uint256 amount, address to) external onlyOperators returns (bool, uint256) {
        return IJonesRouter(router).withdrawRequest(amount, to, 0, "");
    }
}
